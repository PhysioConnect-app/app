-- Schedule the session-reminders edge function to run every 10 minutes.
-- Requires pg_cron and pg_net extensions (both enabled by default on Supabase).
--
-- Replace <project-ref> with your actual Supabase project reference.
-- Replace <service-role-key> with your service role key (store in Vault, not here).
--
-- Run manually after deploying the edge function:
--   supabase functions deploy session-reminders --no-verify-jwt

-- Uncomment and fill in your project ref + service role key, then run:
-- select cron.schedule(
--   'session-reminders',
--   '*/10 * * * *',
--   $$
--     select net.http_post(
--       url     := 'https://<project-ref>.supabase.co/functions/v1/session-reminders',
--       headers := jsonb_build_object(
--         'Authorization', 'Bearer <service-role-key>',
--         'Content-Type',  'application/json'
--       ),
--       body    := '{}'::jsonb
--     )
--   $$
-- );

-- To verify the cron job was created:
-- select * from cron.job where jobname = 'session-reminders';

-- To remove it:
-- select cron.unschedule('session-reminders');
