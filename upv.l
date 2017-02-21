%{

#include <vector>
#include "upv.tab.hpp"
void prompt();
extern int loading;

%}
%x incl
%%
"import"      BEGIN(incl);

<incl>[ \t]*      /* eat the whitespace */
<incl>[^ \t\n]+   { /* got the include file name */
    yyin = fopen( yytext, "r" );
    
    if ( ! yyin ) {
        fprintf(stderr,"Unable to open file %s.\n", yytext);
    } 
	loading++;
	yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE ));
    BEGIN(INITIAL);
}
     
<<EOF>> {
    if( yyin && yyin != stdin )
    	fclose(yyin);
    yypop_buffer_state();
    loading--;
    if ( !YY_CURRENT_BUFFER ) {
        yyterminate();
    }
}

! {
	return EXCL;
}

\? {
	return QUESTION;
}

# {
	return POUND;
}

"!v" {
	return EXCLV;
}

"if" {
	return IF;
}

"else" {
	return ELSE;
}

\-?(0|[1-9][0-9]*) {
	yylval.number_val = atoi(yytext);
	return NUMBER;
}

"u" {
	return UP;
}

"d" {
	return DOWN;
}

"l" {
	return LEFT;
}

"r" {
	return RIGHT;
}

"f" {
	return FORTH;
}

"b" {
	return BACKWARD;
}

"push" {
	// push value in pix at direction
	return PUSH;
}

"slide" {
	// slide user to different pix
	return SLIDE;
}

"scape" {
	// define action in pix
	return SCAPE;
}

"carry" {
	// define action carried
	return CARRY;
}

"," {
	return COMMA;
}

"\)" {
	return CLOSEPAR;
}

"\(" {
	return OPENPAR;
}

"\]" {
	return CLOSEBRACKET;
}

"\[" {
	return OPENBRACKET;
}

"\}" {
	return CLOSECURLY;
}

"\{" {
	return OPENCURLY;
}

\n {
	prompt();
}

[ \t] {
	//discard space
}

\/\/.*$ {
	// comments
}
