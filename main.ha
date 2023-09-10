use fmt;
use io;
use fs;
use os;
use strconv;
use encoding::json;

type invalidop = !void;
type invalidkind = !void;
type unknownvar = !void;
type comperror = !(unknownvar | invalidop | invalidkind);

export fn main() void = {

	if(len(os::args) < 2){
		fmt::fatalf("Usage: {} <ast.json>", os::args[0]);
	};

	const file = match (os::open(os::args[1])) {
	case let f: io::file =>
		yield f;
	case let err: fs::error =>
		fmt::fatalf("Unable to open {}: {}",
			os::args[1], fs::strerror(err));
		};

	const header = match (os::open("header.c")) {
	case let file: io::file =>
		yield file;
	case let err: fs::error =>
		fmt::fatalf("Error opening {}: {}",
			"header.c", fs::strerror(err));
	};

	let file = encoding::json::load(file)!;
	defer encoding::json::finish(file);
	
	let objf = file as encoding::json::object;

	//const name = encoding::json::get(&objf, "name") as str;
	io::copy(os::stdout, header)!;
	compile(xgetobj(&objf, "expression"))!;
	fmt::print("}")!;
};

fn compile(code: encoding::json::object) (void | io::error) = {
	let it = encoding::json::iter(&code);
	
	for(let exp = encoding::json::next(&it); !(exp is void); exp = encoding::json::next(&it)){
		const exp = exp as (const str, const *encoding::json::value);

		switch (exp.0) {
		case "kind" => return kind(&code, *exp.1 as str);
		case "location" => continue;
		case => fmt::fatalf("{} not implemented", exp.0);
		};
	};
};

fn kind(code: *encoding::json::object, kd: str) (void | io::error) = {
	switch(kd){
	case "Print" =>
		fmt::print("print(")!;
		compile(xgetobj(code, "value"))!;
		fmt::print(");")!;
	case "Str" =>
		fmt::printf("\"{}\"", xgetstr(code, "value"))!;
	case "Int" =>
		fmt::print(xgetint(code, "value"))!;
	case "Binary" =>
		// opcode(lhs, rhs, op)
		let op = opcode(&xgetobj(code, "lhs"), 
				&xgetobj(code, "rhs"), 
				xgetstr(code, "op"));
		match(op) {
		// TODO: pretty print errors
		case invalidop => fmt::printfln("Invalid {} operation at:")!;
		case let opstr: str => fmt::printf("\"{}\"", opstr)!;
		case let opint: int => fmt::print(opint)!;
		case let opbool: bool => fmt::print(opbool)!;
		};
	case => fmt::fatalf("Unknown kind: {}", kd);
	};
};

fn opcode(lhs: *encoding::json::object, rhs: *encoding::json::object, op: str) (str | int | bool |  comperror) = {
	const kind1 = xgetstr(lhs, "kind");
	const kind2 = xgetstr(rhs, "kind");

	switch (kind1) {
	case "Int" => 
		switch (kind2) {
		case "Int" => 
			const lv = xgetint(lhs, "value");
			const rv = xgetint(rhs, "value");
			switch (op) {
			case "Add" => return lv + rv;
			case "Sub" => return lv - rv;
			case "Mul" => return lv * rv;
			case "Div" => return lv / rv;
			case "Rem" => return lv % rv;
			case "Eq" => return lv == rv;
			case "Neq" => return lv != rv;
			case "Lt" => return lv < rv;
			case "Gt" => return lv > rv;
			case "Lte" => return lv <= rv;
			case "Gte" => return lv >= rv;
			case => return invalidop;
			};
		case "Binary" =>
			const lv = xgetint(lhs, "value");
			const lrv = xgetobj(rhs, "lhs");
			const rrv = xgetobj(rhs, "rhs");
			const op2 = xgetstr(rhs, "op");
			const rv = opcode(&lrv, &rrv, op2) as int;
			
			switch (op) {
			case "Add" => return lv + rv;
			case "Sub" => return lv - rv;
			case "Mul" => return lv * rv;
			case "Div" => return lv / rv;
			case "Rem" => return lv % rv;
			case "Eq" => return lv == rv;
			case "Neq" => return lv != rv;
			case "Lt" => return lv < rv;
			case "Gt" => return lv > rv;
			case "Lte" => return lv <= rv;
			case "Gte" => return lv >= rv;
			case => return invalidop;
			};
		case "Str" =>
			const lv = xgetint(lhs, "value");
			const rv = xgetstr(rhs, "value");
			switch (op) {
			case "Add" => return fmt::asprintf("{}{}", lv, rv);
			case => return invalidop;
			};
		case => return invalidkind;
		};
	case "Binary" => 
		return opcode(rhs, lhs, op);
	case "Str" => 
		return opcode(rhs, lhs, op);
	case => return invalidop;
	};
};
