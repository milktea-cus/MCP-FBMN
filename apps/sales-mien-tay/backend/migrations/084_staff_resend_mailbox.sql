-- Mailbox assignment is distinct from login email and unique across staff.
CREATE TABLE IF NOT EXISTS public.staff_mailboxes (
 user_sub text PRIMARY KEY REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 mailbox text NOT NULL UNIQUE,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by text NOT NULL REFERENCES public.staff_members(user_sub),
 CONSTRAINT staff_mailboxes_address CHECK (
   mailbox = lower(mailbox) AND mailbox ~ '^[a-z0-9._+-]+@fbmn[.]vn$'
 )
);
REVOKE ALL ON public.staff_mailboxes FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.staff_mailboxes TO sales_api;
CREATE INDEX IF NOT EXISTS staff_mailboxes_mailbox_lookup ON public.staff_mailboxes(mailbox);
