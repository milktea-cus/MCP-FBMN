-- 062: Human-readable names for versioned working-with-customer forms.
-- Additive only: existing survey sessions keep their immutable template_id.
ALTER TABLE public.field_survey_templates
 ADD COLUMN IF NOT EXISTS title text NOT NULL DEFAULT 'Mẫu làm việc với khách';
UPDATE public.field_survey_templates
 SET title = CASE WHEN province='*'
    THEN 'Mẫu chung · Gặp khách'
    ELSE LEFT('Mẫu gặp khách · ' || province, 80) END
 WHERE title='Mẫu làm việc với khách';
ALTER TABLE public.field_survey_templates
 ADD CONSTRAINT field_survey_template_title_nonblank
 CHECK (length(btrim(title)) BETWEEN 2 AND 80);
