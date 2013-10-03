/*------------------------------------------------------------------------*\
** Program : SAS-write-turtle.sas
** Purpose : Write a dataset as turtle converting some of the types
\*------------------------------------------------------------------------*/

/*

Install ruby
Source http://rubyinstaller.org/downloads/

Install jena 
http://www.apache.org/dist/jena/binaries/
http://www.apache.org/dist/jena/binaries/jena-fuseki-0.2.7-distribution.zip

Follow 
https://jena.apache.org/documentation/serving_data/

Commands in window asuming jena-fuseki is installed in \opt\jena-fuseki-0.2.7
cd \opt\jena-fuseki-0.2.7
fuseki-server --update --mem /ds 

Start a new window assuming that the output from this program - sasdump.ttl - is in the 
same directory.

cd \opt\jena-fuseki-0.2.7

ruby s-put http://localhost:3030/ds/data default sasdump.ttl

ruby s-query --service http://localhost:3030/ds/query 'SELECT * {?s ?p ?o}'


In browser:
http://localhost:3030/

select Control Panel
http://localhost:3030/control-panel.tpl

ensure the display shows /ds, click select

Try some queries from the browser.
SELECT * {?s ?p ?o}

Reconstruct the dataset with the following SPARQL query
(also gets the row name)

PREFIX ds: <http://example.org/sasdataset#> 
PREFIX dsv: <http://example.org/sasdataset-variable#> 
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 

SELECT * {
?row rdf:type ds:SASHELP.CLASS ;
 dsv:Name ?Name ;
 dsv:Sex ?Sex ;
 dsv:Age ?Age ; 
 dsv:Height ?Height;
 dsv:Weight ?Weight .
}

Alternatively, use file in get-sashelp-class.rq
ruby s-query --service http://localhost:3030/ds/query --query=get-sashelp-class.rq

*/


proc contents data=sashelp._all_ ; 
ods output attributes=attr;
run;



data dswrite;
   set attr(where=(cValue1="DATA"));
   if upcase(member) in ("SASHELP.CLASS", "SASHELP.CARS") ;
   length ttlfilename $200;
   /* 
   * one ttl for each dataset;
   ttlfilename= cats(translate(member,".","-"),".ttl");
    */

   * same ttl for all dataset;
   ttlfilename= cats("sasdump", ".ttl");

   keep member ttlfilename;
   putlog member= ttlfilename=;
run;


filename dummy "dummy-write.ttl";


data _null_;

    %let maxl=$2048;
    %let outlinelen=$3072;
    length line &outlinelen.; /* maximal length of text line */
    length stext ptext otext &outlinelen.; 
    length xsvaluec &maxl.; /* maximal length of any character variable */
    length xsdsn $32 xsvar $32;
    length xsfmt $33;
    length indsn $65;

    set dswrite;
    t_ttlfilename=ttlfilename;
    file dummy filevar=t_ttlfilename lrecl=1024; 

    if _n_=1 then do;
        put "@prefix ds: <http://example.org/sasdataset#> .";
        put "@prefix dsv: <http://example.org/sasdataset-variable#> .";
        put "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .";
        put "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .";
        put " ";
    end;

    indsn=member;
    putlog " opening ... " indsn= ;
    dsid=open(indsn,"i");
    if dsid=0 then do;
        put "Could not open " indsn=;
        abort cancel;
        end;
    xsdsn=indsn;
    num=attrn(dsid,"nvars");
    nobs=attrn(dsid,"nobs");


    do j=1 to nobs;
        rc= fetchobs(dsid, j);
        stext= cats("_:", j, "_", indsn );
        ptext= "rdf:type";
        otext= cats("ds:", indsn );
        indentpos=1;
        put;
        do i=1 to num;
            line= catx(" ", stext, ptext, otext, ";" );
            put @indentpos line : +(-1); /* remove trailing blank */
            indentpos=4;
            xsvar=varname(dsid,i);
            xsfmt=varfmt(dsid,i);
            stext=" "; 
            ptext=cats("dsv:", xsvar);
            /* Determine type from format, to make it easier to later add all datetime, date and time formats */
            /* The code below is inefficient. Using a lookup table could be faster, and mapping could be determined initially */
            select;
            when (vartype(dsid,i)="N" and xsfmt="E8601DT.") do;
                xsvaluen= getvarn( dsid, i);            
                otext= cats(quote(strip(put(xsvaluen,E8601DT.))),"^^xsd:dateTime");
                end;
            when (vartype(dsid,i)="N" and xsfmt="E8601DA.") do;
                xsvaluen= getvarn( dsid, i);
                otext= cats(quote(strip(put(xsvaluen,E8601DA.))),"^^xsd:date");
                end;
            when (vartype(dsid,i)="N" and xsfmt="E8601TM.") do;
                xsvaluen= getvarn( dsid, i);
                otext= cats(quote(strip(put(xsvaluen,E8601TM.))),"^^xsd:time");
                end;
            when (vartype(dsid,i)="N" and xsfmt=:"E") do;
                xsvaluen= getvarn( dsid, i);
                otext= cats(quote(strip(vvalue(xsvaluen))),"^^xsd:float");
                end;
            when (vartype(dsid,i)="N") do;
                /* Assuming everything else is float and representing as float */
                xsvaluen= getvarn( dsid, i);
                otext= cats(quote(strip(put(xsvaluen,e32.))),"^^xsd:float");
                end;
            when (vartype(dsid,i)="C") do;
                xsvaluec= getvarc( dsid, i);
                /* Using trim to avoid trailing blanks. Deliberately not stripping leading blanks */
                otext= quote(trim(xsvaluec));
                end;
                end; /* select */
           end;
            line= catx(" ", stext, ptext, otext, "." );
            put @indentpos line : +(-1); /* remove trailing blank */
        end;
    /* === All done for dataset === */
    rc=close(dsid);

run;
