-- Each Resend inbox has its own signature, independent of the employee
-- currently assigned to it. Never copy a signature to another mailbox.
CREATE TABLE IF NOT EXISTS public.staff_mailbox_signatures (
 mailbox text PRIMARY KEY,
 signature_text text NOT NULL DEFAULT '',
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by text NOT NULL REFERENCES public.staff_members(user_sub),
 CONSTRAINT staff_mailbox_signatures_address CHECK (
   mailbox = lower(mailbox) AND mailbox ~ '^[a-z0-9._+-]+@fbmn[.]vn$'
 ),
 CONSTRAINT staff_mailbox_signatures_length CHECK (
   char_length(signature_text) <= 3000
 )
);
REVOKE ALL ON public.staff_mailbox_signatures FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE ON public.staff_mailbox_signatures TO sales_api;
