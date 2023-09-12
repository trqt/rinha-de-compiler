use encoding::json;
use fmt;

fn xgetobj(value: *encoding::json::object, s: str) encoding::json::object = {
	const ret = encoding::json::get(value, s);

	if(ret is void) {
		fmt::fatalf("Morri obj");
	};

	const ret = ret as *encoding::json::value;
	const ret = *ret as encoding::json::object;

	return ret;
};

fn xgetstr(value: *encoding::json::object, s: str) str = {
	const ret = encoding::json::get(value, s);

	if(ret is void) {
		fmt::fatalf("Morri str");
	};

	const ret = ret as *encoding::json::value;
	const ret = *ret as str;

	return ret;
};

fn xgetint(value: *encoding::json::object, s: str) int = {
	const ret = encoding::json::get(value, s);

	if(ret is void) {
		fmt::fatalf("Morri int");
	};

	const ret = ret as *encoding::json::value;
	const ret = *ret as f64;

	return ret: int;
};

fn xgetbool(value: *encoding::json::object, s: str) bool = {
	const ret = encoding::json::get(value, s);

	if(ret is void) {
		fmt::fatalf("Morri bool");
	};

	const ret = ret as *encoding::json::value;
	const ret = *ret as bool;

	return ret;
};


