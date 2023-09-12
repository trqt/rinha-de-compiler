use fmt;
use io;
use fs;
use os;
use strconv;
use strings;
use encoding::json;

type invalidop = !void;
type invalidkind = !void;
type unknownvar = !void;
type comperror = !(unknownvar | invalidop | invalidkind);

type kinds = (str | int | bool);

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
		case "kind" => return kind(&code, *exp.1 as str)!;
		case "next" => return compile(*exp.1 as encoding::json::object);
		case "location" => continue;
		case "name" => continue;
		case "value" => continue;
		case => fmt::fatalf("{} not implemented", exp.0);
		};
	};
};

fn newlet(let_ex: *encoding::json::object) (void | io::error) = {
	const valobj = xgetobj(let_ex, "value");
	const kind = xgetstr(&valobj, "kind"); 
	if(kind == "Function") return;
	if(kind == "Call") return;

	const name = xgetstr(&xgetobj(let_ex, "name"), "text");
	switch (kind) {
	case "Int" => fmt::printfln("int {} = {};", name, xgetint(&valobj, "value"))!;
	case  => fmt::println("TODO")!;
	};
	

};

fn kind(code: *encoding::json::object, kd: str) (void | io::error) = {
	const location = &xgetobj(code, "location");
	const locstart = xgetint(location, "start");
	const locend = xgetint(location, "end");
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
		// binary(lhs, rhs, op)
		let op = binary(&xgetobj(code, "lhs"), 
				&xgetobj(code, "rhs"), 
				xgetstr(code, "op"));

		match(op) {
		// TODO: pretty print errors
		case invalidop => fmt::errorfln("\x1b[31mInvalid operation at {}-{}", locstart, locend)!;
		case let opstr: str => fmt::printf("\"{}\"", opstr)!;
		case let opint: int => fmt::print(opint)!;
		case let opbool: bool => fmt::print(opbool)!;
		};
	case "Let" => return newlet(code);
	case => fmt::fatalf("Unknown kind: {}", kd);
	};
};

fn binary(lhs: *encoding::json::object, rhs: *encoding::json::object, op: str) (kinds | comperror) = {
	const kind1 = xgetstr(lhs, "kind");
	const kind2 = xgetstr(rhs, "kind");

	switch (kind1) {
	case "Int" => 
		switch (kind2) {
		case "Int" => 
			const lv = xgetint(lhs, "value");
			const rv = xgetint(rhs, "value");
			
			return opcode(lv, rv, op);
		case "Binary" =>
			const lv = xgetint(lhs, "value");
			const lrv = xgetobj(rhs, "lhs");
			const rrv = xgetobj(rhs, "rhs");
			const opr = xgetstr(rhs, "op");
			const rv = binary(&lrv, &rrv, opr);
			if(rv is comperror) return rv;

			return opcode(lv, rv as kinds, op);

		case "Str" =>
			const lv = xgetint(lhs, "value");
			const rv = xgetstr(rhs, "value");

			return opcode(lv, rv, op);
			
		case => return invalidop;
		};
	case "Bool" =>
		switch(kind2) {
		case "Binary" => 
			const lv = xgetbool(lhs, "value");
			const lrv = xgetobj(rhs, "lhs");
			const rrv = xgetobj(rhs, "rhs");
			const opr = xgetstr(rhs, "op");
			const rv = binary(&lrv, &rrv, opr);
			if(rv is comperror) return rv;

			return opcode(lv, rv as kinds, op);

		case "Bool" =>
			const lv = xgetbool(lhs, "value");
			const rv = xgetbool(rhs, "value");

			return opcode(lv, rv, op);
		case => return invalidop;
		};
	case "Binary" =>
		const llv = xgetobj(lhs, "lhs");
		const rlv = xgetobj(lhs, "rhs");
		const opl = xgetstr(lhs, "op");
		const lv = binary(&llv, &rlv, opl);
		if(lv is comperror) return lv;

		const lrv = xgetobj(rhs, "lhs");
		const rrv = xgetobj(rhs, "rhs");
		const opr = xgetstr(rhs, "op");
		const rv = binary(&lrv, &rrv, opr);
		if(rv is comperror) return rv;

		return opcode(lv as kinds, rv as kinds, op);
	case "Str" => 
		switch(kind2) {
		case "Str" =>
			const lv = xgetstr(lhs, "value");
			const rv = xgetstr(rhs, "value");
			return opcode(lv, rv, op);
		case "Int" =>
			const lv = xgetstr(lhs, "value");
			const rv = xgetint(rhs, "value");
			return opcode(lv, rv, op);
		case "Binary" => 
			const lv = xgetstr(lhs, "value");
			const lrv = xgetobj(rhs, "lhs");
			const rrv = xgetobj(rhs, "rhs");
			const opr = xgetstr(rhs, "op");
			const rv = binary(&lrv, &rrv, opr);
			if(rv is comperror) return rv;

			return opcode(lv, rv as kinds, op);
		case => return invalidop;
		};
	case => return invalidop;
	};
};
fn opcode(lhs: kinds, rhs: kinds, op: str) (kinds | comperror) = {
	switch (op) {
	case "Add" =>
		if(lhs is int && rhs is int) return lhs as int + rhs as int;
		if(lhs is str && rhs is str) return strings::concat(lhs as str, rhs as str);
		if(lhs is str && rhs is int) return fmt::asprintf("{}{}", lhs, rhs);
		if(lhs is int && rhs is str) return fmt::asprintf("{}{}", lhs, rhs);
		return invalidop;
	case "Eq" =>
		if(lhs is int && rhs is int)   return lhs as int  == rhs as int;
		if(lhs is str && rhs is str)   return lhs as str  == rhs as str;
		if(lhs is bool && rhs is bool) return lhs as bool == rhs as bool;
	case "Neq" =>
		if(lhs is int && rhs is int)   return lhs as int  != rhs as int;
		if(lhs is str && rhs is str)   return lhs as str  != rhs as str;
		if(lhs is bool && rhs is bool) return lhs as bool != rhs as bool;
		return invalidop;
	case "And" =>
		if(lhs is bool && rhs is bool) return lhs as bool && rhs as bool;
		return invalidop;
	case "Or" =>
		if(lhs is bool && rhs is bool) return lhs as bool || rhs as bool;
		return invalidop;
	case => 
		if(!(lhs is int && rhs is int)) return invalidop;
		const lhs = lhs as int;
		const rhs = rhs as int;
		switch (op) {
		case "Sub" => return lhs - rhs;
		case "Mul" => return lhs * rhs;
		case "Div" => 
			if(rhs == 0) return invalidop;
			return lhs / rhs;
		case "Rem" => return lhs % rhs;
		case "Lt" => return lhs < rhs;
		case "Gt" => return lhs > rhs;
		case "Lte" => return lhs <= rhs;
		case "Gte" => return lhs >= rhs;
		case => return invalidop;
		};
	};

	return invalidop;
};


