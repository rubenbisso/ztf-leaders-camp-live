import sql, { json, FINANCE_FIELD_LABELS } from './_db.mjs';

// Same shape as export.mjs, for the independent finance_returns table.
// id is internal row-linking plumbing with no meaning to a reader, so it's
// left out; a row is already identified by name and date.
function csvEscape(v) {
  if (v === null || v === undefined) return '';
  let s;
  if (v instanceof Date) s = v.toISOString();
  else if (typeof v === 'object') s = JSON.stringify(v);
  else s = String(v);
  return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

export default async (req) => {
  const token = new URL(req.url).searchParams.get('token');
  if (!process.env.MIGRATE_TOKEN || token !== process.env.MIGRATE_TOKEN) {
    return json({ error: 'forbidden' }, 403);
  }
  try {
    const rows = await sql`SELECT * FROM finance_returns ORDER BY submitted_at`;
    const lines = [FINANCE_FIELD_LABELS.map(([, label]) => csvEscape(label)).join(',')];
    for (const r of rows) lines.push(FINANCE_FIELD_LABELS.map(([col]) => csvEscape(r[col])).join(','));
    const date = new Date().toISOString().slice(0, 10);
    return new Response(lines.join('\r\n'), {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="imitators-of-ztf-finances-export-${date}.csv"`,
        'Cache-Control': 'no-store'
      }
    });
  } catch (err) {
    console.error('Finance export failed:', err.message);
    return json({ error: 'export_failed' }, 500);
  }
};

export const config = { path: '/api/export-finances' };
