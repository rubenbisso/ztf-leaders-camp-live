// Applies schema.sql as part of every deploy.
//
// Why this exists: the schema used to be applied only by calling
// /api/migrate by hand after deploying. Continuous deployment ships code,
// never the database, so one forgotten call left the code inserting a column
// the table did not have. Every submission then died with a bare 500 and
// Postgres 42703, the finances table did not exist, and a dropped view was
// never recreated. The form was completely down for a day and nobody could
// see why from the outside.
//
// Running it here means the database can never lag behind the code that was
// just deployed. schema.sql is idempotent by design (CREATE TABLE IF NOT
// EXISTS, ADD COLUMN IF NOT EXISTS, guarded renames), so re-running it on
// every build is safe.
//
// It fails the build on error, on purpose. A blocked deploy is a problem
// somebody notices immediately; a deployed site whose database is one column
// behind is a problem members discover by losing their answers.
import postgres from 'postgres';
import { readFile } from 'node:fs/promises';

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('build-migrate: DATABASE_URL is not set. Refusing to publish a build whose database state is unknown.');
  console.error('build-migrate: set it under Site configuration, Environment variables, or set SKIP_MIGRATE=1 to bypass deliberately.');
  process.exit(1);
}
if (process.env.SKIP_MIGRATE === '1') {
  console.log('build-migrate: SKIP_MIGRATE=1, skipping on purpose.');
  process.exit(0);
}

// Notices are silenced: an idempotent schema emits one "already exists" per
// object, which buries the one line that matters in the build log.
const sql = postgres(url, { max: 1, idle_timeout: 20, connect_timeout: 20, prepare: false, ssl: 'require', onnotice: () => {} });
try {
  const schema = await readFile(new URL('./functions/schema.sql', import.meta.url), 'utf8');
  await sql.unsafe(schema);

  // Prove the database now matches what the functions expect, rather than
  // trusting that the script ran. This is the check whose absence let the
  // outage happen: the code knew about month_number, the table did not.
  const { COLUMNS } = await import('./functions/_db.mjs');
  const present = (await sql`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'accountability_returns'
  `).map(r => r.column_name);
  const missing = COLUMNS.filter(c => !present.includes(c));
  if (missing.length) {
    console.error('build-migrate: schema applied but these columns the code writes are still absent:', missing.join(', '));
    process.exit(1);
  }
  console.log(`build-migrate: schema applied, all ${COLUMNS.length} written columns present.`);
} catch (err) {
  console.error('build-migrate: failed:', err.message);
  process.exit(1);
} finally {
  await sql.end({ timeout: 5 });
}
