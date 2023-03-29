implement Finger;

include "sys.m";
	sys: Sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "dial.m";
	dial: Dial;

Finger: module {
	init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string) {
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	dial = load Dial Dial->PATH;

	arg->init(args);
	arg->setusage("finger [ -v ] user@host");

	stderr := sys->fildes(2);

	verbose := "";
	while((c := arg->opt()) != 0) {
		case c {
		'v' =>
			verbose = "/W";
		* =>
			arg->usage();
		}
	}

	args = arg->argv();
	if(len args != 1)
		arg->usage();

	host := "localhost";
	user := hd args;
	for(i := len user - 1; i >= 0; i--) {
		if(user[i] == '@') {
			host = user[i+1:];
			user = user[0:i];
			break;
		}
	}

	if(verbose != "" && user != "")
		verbose += " ";

	conn := dial->dial(dial->netmkaddr(host, "tcp", "79"), nil);
	if(conn == nil) {
		sys->fprint(stderr, "finger: can't dial host: %r\n");
		raise "fail:dial";
	}

	if(sys->fprint(conn.dfd, "%s%s\r\n", verbose, user) < 0) {
		sys->fprint(stderr, "finger: can't write to host: %r\n");
		raise "fail:fprint";
	}

	in := bufio->fopen(conn.dfd, bufio->OREAD);
	out := bufio->fopen(sys->fildes(1), bufio->OWRITE);

	while((c = in.getb()) != bufio->EOF) {
		case c {
		' ' to '~' or '\n' or '\t' =>
			out.putb(byte c);
		bufio->ERROR =>
			sys->fprint(stderr, "finger: can't read from host: %r\n");
			raise "fail:getb";
		}
	}

	in.close();
	out.flush();
}