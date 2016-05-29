
    %let maxl=$2048;
    %let outlinelen=$3072;
    

filename dummy "dummy-write.ttl";


data _null_;

    length dsprefix $1024 dsvprefix $1024 ttlfilename $1024 subjectprefix $1024;
    
    length line &outlinelen.; /* maximal length of text line */
    length stext ptext otext &outlinelen.; 
    length xsvaluec &maxl.; /* maximal length of any character variable */
    length xsdsn $32 xsvar $32;
    length xsfmt $33;
    length indsn $65;

    set dswrite;

    if missing(dsprefix) then do;
        dsprefix="http://example.org/sasdataset#";
        end;
    if missing(dsvprefix) then do;
        dsvprefix="http://example.org/sasdataset-variable#";
        end;

    if missing(ttlfilename) then do;
       ttlfilename= cats("sasdump", ".ttl");
       end;

   if missing(subjectprefix) then do;
       subjectprefix="_:";
       end;
   
    t_ttlfilename=ttlfilename;
    file dummy filevar=t_ttlfilename lrecl=1024; 

    if _n_=1 then do;
        put "@prefix ds: " "<" dsprefix : +(-1) ">" " .";
        put "@prefix dsv: " "<" dsvprefix : +(-1) ">" " .";
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
        stext= cats(subjectprefix, j, "_", indsn );
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
