-- 025: Correct Vietnamese transliteration of the name component.
-- During one atomic transaction allow a NULL field_code to trigger regeneration.
-- The final trigger restores immutability before COMMIT; other sessions never
-- observe the temporary behavior, and customer UUID/ERP code/version stay intact.
BEGIN;
CREATE OR REPLACE FUNCTION public.field_customer_code_root(p_name text,p_province text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $root$
DECLARE a text; n text; p text[]; w text[]; place text; who text;
BEGIN
 a:=regexp_replace(translate(lower(coalesce(p_province,'')),'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ','aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'),'[^a-z0-9]+',' ','g');
 n:=regexp_replace(translate(lower(coalesce(p_name,'')),'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ','aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'),'[^a-z0-9]+',' ','g');
 p:=regexp_split_to_array(btrim(a),'\s+');
 w:=regexp_split_to_array(btrim(n),'\s+');
 IF array_length(p,1)>1 THEN
   place:=substr(p[1],1,1)||substr(p[array_length(p,1)],1,1);
 ELSE
   place:=substr(coalesce(p[1],'XX')||'XX',1,2);
 END IF;
 IF array_length(w,1)>1 THEN
   who:=substr(w[array_length(w,1)-1],1,1)||substr(w[array_length(w,1)],1,1);
 ELSE
   who:=substr(coalesce(w[1],'XX')||'XX',1,2);
 END IF;
 RETURN upper(substr(coalesce(place,'XX')||'XX',1,2)||
              substr(coalesce(who,'XX')||'XX',1,2));
END $root$;
CREATE OR REPLACE FUNCTION public.field_customer_code_assign()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $trg$
DECLARE prefix text; candidate text; ix integer;
BEGIN
 -- Field Work code is immutable. The company/import code stays in customers.code.
 IF TG_OP='UPDATE' AND OLD.field_code IS NOT NULL AND NEW.field_code IS NOT NULL THEN
   NEW.field_code:=OLD.field_code;
   RETURN NEW;
 END IF;
 -- Enforce server-generated codes: offline clients cannot spoof code identity.
 PERFORM pg_advisory_xact_lock(hashtext('field-work:customer-codes'));
 prefix:=public.field_customer_code_root(NEW.name,NEW.province);
 FOR ix IN 1..1295 LOOP
  candidate:=prefix||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',(ix/36)+1,1)||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',mod(ix,36)+1,1);
  IF NOT EXISTS(SELECT 1 FROM public.customers WHERE field_code=candidate)
    THEN NEW.field_code:=candidate; RETURN NEW; END IF;
 END LOOP;
 RAISE EXCEPTION 'field_customer_code_exhausted';
END $trg$;
DO $repair$
DECLARE rec record;
BEGIN
 FOR rec IN SELECT id FROM public.customers
   WHERE substring(field_code,1,4)<>public.field_customer_code_root(name,province)
   ORDER BY created_at,id LOOP
  UPDATE public.customers SET field_code=NULL WHERE id=rec.id;
 END LOOP;
END $repair$;
CREATE OR REPLACE FUNCTION public.field_customer_code_assign()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $trg$
DECLARE prefix text; candidate text; ix integer;
BEGIN
 -- Field Work code is immutable. The company/import code stays in customers.code.
 IF TG_OP='UPDATE' AND OLD.field_code IS NOT NULL THEN
   NEW.field_code:=OLD.field_code;
   RETURN NEW;
 END IF;
 -- Enforce server-generated codes: offline clients cannot spoof code identity.
 PERFORM pg_advisory_xact_lock(hashtext('field-work:customer-codes'));
 prefix:=public.field_customer_code_root(NEW.name,NEW.province);
 FOR ix IN 1..1295 LOOP
  candidate:=prefix||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',(ix/36)+1,1)||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',mod(ix,36)+1,1);
  IF NOT EXISTS(SELECT 1 FROM public.customers WHERE field_code=candidate)
    THEN NEW.field_code:=candidate; RETURN NEW; END IF;
 END LOOP;
 RAISE EXCEPTION 'field_customer_code_exhausted';
END $trg$;
COMMIT;
