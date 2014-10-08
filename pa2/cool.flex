/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_level;
int string_length = 0;

void add_to_string_buf(char* str);
void string_buf_reset();
bool str_too_long();
int str_too_long_error();
%}

/*
 * Define names for regular expressions here.
 */

DARROW	=>
LE	<=
ASSIGN	<-
TYPE	[A-Z][a-zA-Z0-9_]*
OBJECT 	[a-z][a-zA-Z0-9_]*
DIGIT	[0-9]
WHITESPACE	[\ \f\r\t\v]


%x STRING
%x COMMENT
%x DASHCOMMENT
%x BROKENSTRING
%%

 /*
  *  Nested comments
  */
<INITIAL,COMMENT>"(*"	{ comment_level++; BEGIN(COMMENT); }
<COMMENT>\n	{ curr_lineno++; }
<COMMENT>.	{;}
<COMMENT>"*)"	{
	comment_level--;
	if(comment_level == 0) { 
		BEGIN(INITIAL);
	}
}
<COMMENT><<EOF>>	{
	BEGIN(INITIAL);
	cool_yylval.error_msg = "unexpected EOF";
	return (ERROR);
}
<INITIAL>"*)"	{
	cool_yylval.error_msg = "unmatched comment closure";
	return (ERROR);
}

--	BEGIN(DASHCOMMENT);
<DASHCOMMENT>[^\n]	{;}
<DASHCOMMENT>[\n]	{ curr_lineno++; BEGIN(INITIAL); }
<DASHCOMMENT><<EOF>>	yyterminate();

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{LE}		{ return (LE); }
{ASSIGN}		{ return (ASSIGN); }

"/"             { return '/'; }
"+"             { return '+'; }
"-"             { return '-'; }
"*"             { return '*'; }
"("             { return '('; }
")"             { return ')'; }
"="             { return '='; }
"<"             { return '<'; }
"."             { return '.'; }
"~"             { return '~'; }
","             { return ','; }
";"             { return ';'; }
":"             { return ':'; }
"@"             { return '@'; }
"{"             { return '{'; }
"}"             { return '}'; }
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)	{ return (CLASS); }
(?i:else)	{ return (ELSE); }
f(?i:alse)	{ cool_yylval.boolean = false; return (BOOL_CONST); }
(?i:if)		{ return (IF); }
(?i:fi)		{ return (FI); }
(?i:in)		{ return (IN); }
(?i:inherits)	{ return (INHERITS); }
(?i:isvoid)	{ return (ISVOID); }
(?i:let)	{ return (LET); }
(?i:loop)	{ return (LOOP); }
(?i:pool)	{ return (POOL); }
(?i:then)	{ return (THEN); }
(?i:while)	{ return (WHILE); }
(?i:case)	{ return (CASE); }
(?i:esac)	{ return (ESAC); }
(?i:new)	{ return (NEW); }
(?i:of)		{ return (OF); }
(?i:not)	{ return (NOT); }
t(?i:rue)	{ cool_yylval.boolean = true; return (BOOL_CONST); }
 
{DIGIT}+	{
	cool_yylval.symbol = inttable.add_string( yytext );
	return (INT_CONST); 
}
{OBJECT}	{ cool_yylval.symbol = idtable.add_string(yytext); return (OBJECTID); }
{TYPE}		{ cool_yylval.symbol = idtable.add_string(yytext); return (TYPEID); }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\"	{
	BEGIN(STRING);
}

<STRING>\"	{
	cool_yylval.symbol = stringtable.add_string(string_buf);
	string_buf_reset();
	BEGIN(INITIAL);
	return (STR_CONST);
}

<STRING>(\0|\\\0)	{
	BEGIN(BROKENSTRING);
	cool_yylval.error_msg = "string contains null";
	return (ERROR);
}
	
<BROKENSTRING>.*[\"\n]	{
	BEGIN(INITIAL);
}
	
<STRING>\\\n	{
	if( str_too_long() ) { return str_too_long_error(); }
	curr_lineno++;
	string_length ++;
	add_to_string_buf("\n");
}

<STRING>\n	{
	cool_yylval.error_msg = "string not terminated";
	curr_lineno++;
	BEGIN(INITIAL);
	string_buf_reset();
	return (ERROR);
}

<STRING><<EOF>>	{
	BEGIN(INITIAL);
	cool_yylval.error_msg = "EOF in string constant";
	return (ERROR);
}

<STRING>\\n	{
	if( str_too_long() ) { return str_too_long_error(); }
	string_length++;
	add_to_string_buf("\n");
}
<STRING>\\t	{
        if( str_too_long() ) { return str_too_long_error(); }
        string_length++;
	add_to_string_buf("\t");
}
	
<STRING>\\b	{
        if( str_too_long() ) { return str_too_long_error(); }
        string_length++;
	add_to_string_buf("\b");
}

<STRING>\\f	{
        if( str_too_long() ) { return str_too_long_error(); }
	string_length++;
	add_to_string_buf("\f");
}

<STRING>\\.	{
        if( str_too_long() ) { return str_too_long_error(); }
        string_length++;
	add_to_string_buf(&strdup(yytext)[1]);
}

<STRING>.	{
        if( str_too_long() ) { return str_too_long_error(); }
        string_length++;
	add_to_string_buf(yytext);
}

"\n"		{ curr_lineno ++;}
{WHITESPACE}	{;}
.		{ cool_yylval.error_msg = yytext; return (ERROR); }

%%
void add_to_string_buf(char* str) {
	strcat(string_buf, str);
}

void string_buf_reset(void) {
	string_length = 0;
	string_buf[0] = '\0';
}

bool str_too_long( ) {
	if(string_length+1 >= MAX_STR_CONST)	{
		BEGIN(BROKENSTRING);
		return true;
	}
	return false;
}

int str_too_long_error( ) {
	string_buf_reset();
	cool_yylval.error_msg ="string too long";
	return ERROR;	
}
