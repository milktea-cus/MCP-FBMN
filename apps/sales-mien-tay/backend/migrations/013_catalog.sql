-- 013: product catalogue, immutable company code, audit and customer mapping.
BEGIN;
CREATE TABLE public.catalog_products (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_code text NOT NULL UNIQUE CHECK(length(company_code) BETWEEN 1 AND 80),
 sku text, name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 240),
 brand text, category text, unit text, product_spec jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(product_spec)='object'),
 active boolean NOT NULL DEFAULT true, version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX catalog_products_name ON public.catalog_products(lower(name));
CREATE TABLE public.catalog_edits (
 op_id uuid PRIMARY KEY, actor_sub text NOT NULL, product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 before_data jsonb, after_data jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX catalog_edits_recent ON public.catalog_edits(created_at DESC);
CREATE TABLE public.catalog_customer_mapping (
 customer_id uuid PRIMARY KEY REFERENCES public.customers(id) ON DELETE RESTRICT,
 company_code text NOT NULL CHECK(length(company_code) BETWEEN 1 AND 80),
 version integer NOT NULL DEFAULT 1 CHECK(version>0), updated_by text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now(),
 last_op uuid NOT NULL
);
CREATE INDEX catalog_customer_company ON public.catalog_customer_mapping(company_code);
REVOKE DELETE ON public.catalog_products,public.catalog_customer_mapping,public.catalog_edits FROM sales_api;
REVOKE UPDATE ON public.catalog_edits FROM sales_api;
GRANT SELECT,INSERT,UPDATE ON public.catalog_products,public.catalog_customer_mapping TO sales_api;
GRANT SELECT,INSERT ON public.catalog_edits TO sales_api;
COMMIT;
