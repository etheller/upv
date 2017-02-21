
%code requires {
	#include <vector>
	#include <stdio.h>
	#include <vector>
	#include <unordered_map>
	using namespace std;
	typedef tuple<int,int,int> point;
	enum Direction { dUP, dDOWN, dLEFT, dRIGHT, dFORTH, dBACKWARD };

	enum NumberType { CONSTANT, CURRENT, LOOKUP };

	struct Number {
		NumberType type;
		int amount;
		point offset;
	};
}

%token <number_val> NUMBER
%token UP DOWN LEFT RIGHT FORTH BACKWARD
%token PUSH SLIDE SCAPE IF ELSE CARRY POUND
%token OPENBRACKET CLOSEBRACKET COMMA EXCL OPENCURLY CLOSECURLY EXCLV OPENPAR CLOSEPAR QUESTION
%type <dir_val> direction
%type <dirlist_val> path bracketed_path
%type <code_val> statement
%type <code_list> statements block
%type <struct_number_val> amount

%union {
	int number_val;
	struct Number* struct_number_val;
	Direction dir_val;
	vector<Direction>* dirlist_val;
	struct Statement* code_val;
	vector<struct Statement*>* code_list;
}

%{
using namespace std;
int yylex(void);
void yyerror(const char *);

int loading;
template<class T>
inline void hash_combine(size_t & seed, const T & v)
{
	hash<T> hasher;
	seed ^= hasher(v) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
}

namespace std
{
	template<typename S, typename T, typename U> struct hash<tuple<S, T, U>>
	{
		inline size_t operator()(const tuple<S, T, U> & v) const
		{
			size_t seed = 0;
			::hash_combine(seed, get<0>(v));
			::hash_combine(seed, get<1>(v));
			::hash_combine(seed, get<2>(v));
			return seed;
		}
	};
}

typedef vector<Direction> path;

enum Type { tPUSH, tPUSH_ALL, tIF, tUPDATE, tSLIDE, tSCAPE, tSCAPEGRAB, tCARRY, tVIEW, tGO };

struct Statement {
	Type type;
	Number* number;
	path* dirs;
	vector<Statement*>* code;
	vector<Statement*>* otherwise;
	point pt;
};

unordered_map<point,int> space;
unordered_map<point,unordered_map<int,vector<Statement*>*>> scapes;
unordered_map<int,vector<Statement*>*> carries;
point user(0,0,0);

point endOf(path* p) {
	point pt;
	for( int i = 0; i < p->size(); i++ ) {
		switch( (*p)[i] ) {
		case dUP:
			get<1>(pt)++;
			break;
		case dDOWN:
			get<1>(pt)--;
			break;
		case dRIGHT:
			get<0>(pt)++;
			break;
		case dLEFT:
			get<0>(pt)--;
			break;
		case dFORTH:
			get<2>(pt)++;
			break;
		case dBACKWARD:
			get<2>(pt)--;
			break;
		}
	}
	return pt;
}

Direction opposite(Direction d) {
	switch (d) {
		case dUP:
			return dDOWN;
		case dDOWN:
			return dUP;
		case dLEFT:
			return dRIGHT;
		case dRIGHT:
			return dLEFT;
		case dFORTH:
			return dBACKWARD;
		case dBACKWARD:
			return dFORTH;
	}
	return dUP;
}

point execute(point user, Statement* code, bool doPrint);

point step(point where, Direction dir, bool doPrint) {
	switch( dir ) {
	case dUP:
		get<1>(where)++;
		break;
	case dDOWN:
		get<1>(where)--;
		break;
	case dRIGHT:
		get<0>(where)++;
		break;
	case dLEFT:
		get<0>(where)--;
		break;
	case dFORTH:
		get<2>(where)++;
		break;
	case dBACKWARD:
		get<2>(where)--;
		break;
	}
	Direction opp = opposite(dir);
	if( scapes.count(where) && scapes[where].count((int)opp) ) {
		vector<Statement*>* cmds = scapes[where][(int)opp];
		for( int i = 0; i < cmds->size(); i++ ) {
			where = execute(where, (*cmds)[i], doPrint);
		}
	}
	if( carries.count((int)opp) ) {
		vector<Statement*>* cmds = carries[(int)opp];
		for( int i = 0; i < cmds->size(); i++ ) {
			where = execute(where, (*cmds)[i], doPrint);
		}
	}
	return where;
}

point sum(point a, point b) {
	return point(get<0>(a)+get<0>(b),get<1>(a)+get<1>(b),get<2>(a)+get<2>(b));
}

int evaluate(Number* number, point where) {
	switch(number->type) {
		case CURRENT:
			return space[where];
		case CONSTANT:
			return number->amount;
		case LOOKUP:
			return space[sum(where,number->offset)];
	}
	return 0;
}

point execute(point user, Statement* code, bool doPrint) {
	switch (code->type) {
		case tPUSH:
		{
			point pt = user;
			int amount = evaluate(code->number,user);
			for( int i = 0; i < code->dirs->size(); i++ ) {
				if( space.count(pt) > 0 ) {
					space[pt] -= amount;
				} else {
					space[pt] = -amount;
				}
				pt = step(pt, (*code->dirs)[i], false);
				if( space.count(pt) > 0 ) {
					space[pt] += amount;
				} else {
					space[pt] = amount;
				}
			}
			break;
		}
		case tPUSH_ALL:
		{
			int amt = space[user];
			//int amt = evaluate(code->number,user);
			point pt = user;
			for( int i = 0; i < code->dirs->size(); i++ ) {
				if( space.count(pt) > 0 ) {
					space[pt] -= amt;
				} else {
					space[pt] = -amt;
				}
				pt = step(pt, (*code->dirs)[i], false);
				if( space.count(pt) > 0 ) {
					space[pt] += amt;
				} else {
					space[pt] = amt;
				}
			}
			break;
		}
		case tIF:
		{
			int amount = evaluate(code->number,user);
			if( space[user] == amount ) {
				vector<Statement*>* cmds = code->code;
				for( int i = 0; i < cmds->size(); i++ ) {
					user = execute(user, (*cmds)[i], doPrint);
				}
			} else if (code->otherwise) {
				vector<Statement*>* cmds = code->otherwise;
				for( int i = 0; i < cmds->size(); i++ ) {
					user = execute(user, (*cmds)[i], doPrint);
				}
			}
			break;
		}
		case tSLIDE:
		{
			for( int i = 0; i < code->dirs->size(); i++ ) {
				user = step(user, (*code->dirs)[i], doPrint);
				if( doPrint )
					printf("%d\n",space[user]);
			}
			//user = sum(user,endOf(code->dirs));
			break;
		}
		case tUPDATE:
		{
			int amount = evaluate(code->number,user);
			space[user] += amount;
			break;
		}
		case tVIEW:
		{
			int amount = evaluate(code->number,user);
			printf("%d\n", amount);//space[user]);
			break;
		}
		case tGO:
			user = code->pt;
			break;
		case tSCAPE:
			for( int i = 0; i < code->dirs->size(); i++ ) {
				scapes[user][(int)(*code->dirs)[i]] = code->code;
			}
			break;
		case tSCAPEGRAB:
			for( int i = 0; i < code->dirs->size(); i++ ) {
				scapes[user][(int)(*code->dirs)[i]] = scapes[sum(user,code->pt)][(int)(*code->dirs)[i]];
			}
			break;
		case tCARRY:
			for( int i = 0; i < code->dirs->size(); i++ ) {
				carries[(int)(*code->dirs)[i]] = code->code;
			}
			break;	
	}
	return user;
}

	/*OPENCURLY statements CLOSECURLY
	{
		for( int i = 0; i < $2->size(); i++ ) {
			user = execute(user, (*$2)[i]);
		}
	}*/
%}

%%

goal:
	block
	|
	goal block;
;
	
block:
	statement {
		user = execute(user, $1, true);
	}
	|
	statements statement {
	}
;

statements:
	statement {
		vector<Statement*>* code = new vector<Statement*>;
		code->push_back($1);
		$$ = code;
	}
	|
	statements statement {
		$1->push_back($2);
		$$ = $1;
	}
	| {
		vector<Statement*>* code = new vector<Statement*>;
		$$ = code;
	}
;

statement:
	PUSH amount bracketed_path {
		Statement* code = new Statement();
		code->type = tPUSH;
		code->dirs = $3;
		code->number = $2;
		$$ = code;
	}
	|
	PUSH bracketed_path {
		Statement* code = new Statement();
		code->type = tPUSH_ALL;
		code->dirs = $2;
		$$ = code;
	}
	|
	SLIDE bracketed_path {
		Statement* code = new Statement();
		code->type = tSLIDE;
		code->dirs = $2;
		$$ = code;
	}
	|
	amount EXCL {
		Statement* code = new Statement();
		code->type = tUPDATE;
		code->number = $1;
		$$ = code;
	}
	|
	amount QUESTION {
		Statement* code = new Statement();
		code->type = tVIEW;
		code->number = $1;
		$$ = code;
	}
	|
	SCAPE bracketed_path OPENCURLY statements CLOSECURLY {
		Statement* code = new Statement();
		code->type = tSCAPE;
		code->dirs = $2;
		code->code = $4;
		$$ = code;
	}
	|
	SCAPE bracketed_path bracketed_path {
		Statement* code = new Statement();
		code->type = tSCAPEGRAB;
		code->dirs = $2;
		code->pt = endOf($3);
		$$ = code;
	}
	|
	CARRY bracketed_path OPENCURLY statements CLOSECURLY {
		Statement* code = new Statement();
		code->type = tCARRY;
		code->dirs = $2;
		code->code = $4;
		$$ = code;
	}
	|
	IF amount OPENCURLY statements CLOSECURLY {
		Statement* code = new Statement();
		code->type = tIF;
		code->number = $2;
		code->code = $4;
		code->otherwise = NULL;
		$$ = code;
	}
	|
	IF amount OPENCURLY statements CLOSECURLY ELSE OPENCURLY statements CLOSECURLY {
		Statement* code = new Statement();
		code->type = tIF;
		code->number = $2;
		code->code = $4;
		code->otherwise = $8;
		$$ = code;
	}
	|
	OPENPAR NUMBER COMMA NUMBER COMMA NUMBER CLOSEPAR {
		Statement* code = new Statement();
		code->type = tGO;
		code->pt = point($2,$4,$6);
		$$ = code;
	}
;

amount:
	NUMBER
	{
		Number* number = new Number();
		number->amount = $1;
		number->type = CONSTANT;
		$$ = number;
	}
	|
	POUND
	{
		Number* number = new Number();
		number->type = CURRENT;
		$$ = number;
	}
	|
	POUND path
	{
		Number* number = new Number();
		number->type = LOOKUP;
		number->offset = endOf($2);
		$$ = number;
	}
;
bracketed_path:
	OPENBRACKET path CLOSEBRACKET
	{
		$$ = $2;
	}
	;

path:
	direction
	{
		vector<Direction>* thisPath = new vector<Direction>() ;
		thisPath->push_back($1);
		$$ = thisPath;
	}
	|
    	path COMMA direction
	{
		$1->push_back($3);
		$$ = $1;
	}
;

direction:
	UP {
		$$ = dUP;
	}
	|
	DOWN {
		$$ = dDOWN;
	}
	|
	LEFT {
		$$ = dLEFT;
	}
	|
	RIGHT {
		$$ = dRIGHT;
	}
	|
	FORTH {
		$$ = dFORTH;
	}
	|
	BACKWARD {
		$$ = dBACKWARD;
	}
;

%%

void prompt() {
	if( !loading )
		printf("upv> ");
}

void yyerror(const char* error) {
	printf("Syntax error: %s\n", error);
}

int main() {
	prompt();
	yyparse();
}

