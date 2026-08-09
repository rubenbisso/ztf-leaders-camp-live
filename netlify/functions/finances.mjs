import sql, { buildFinanceRow, json } from './_db.mjs';

export default async (req) => {
  if (req.method === 'POST') {
    let body;
    try {
      body = await req.json();
    } catch {
      return json({ error: 'invalid_json' }, 400);
    }

    if (!body?.full_name || !String(body.full_name).trim()) {
      return json({ error: 'missing_name' }, 400);
    }

    const row = buildFinanceRow(body);

    try {
      const [saved] = await sql`
        INSERT INTO finance_returns ${sql(row)}
        RETURNING id, submitted_at
      `;
      return json(saved, 201);
    } catch (err) {
      console.error('Finance insert failed:', err.message);
      return json({ error: 'insert_failed' }, 500);
    }
  }

  if (req.method === 'GET') {
    // Unlike GET /api/returns (an unauthenticated trimmed summary for
    // province secretaries), this data includes email and explicit
    // savings/debt figures — gated behind the same admin token as
    // /api/people and /api/export instead.
    const token = new URL(req.url).searchParams.get('token');
    if (!process.env.MIGRATE_TOKEN || token !== process.env.MIGRATE_TOKEN) {
      return json({ error: 'forbidden' }, 403);
    }
    const limit = Math.min(
      parseInt(new URL(req.url).searchParams.get('limit'), 10) || 100,
      500
    );
    try {
      const rows = await sql`
        SELECT * FROM finance_returns
        ORDER BY submitted_at DESC
        LIMIT ${limit}
      `;
      return json(rows);
    } catch (err) {
      console.error('Finance query failed:', err.message);
      return json({ error: 'query_failed' }, 500);
    }
  }

  return json({ error: 'method_not_allowed' }, 405);
};

export const config = { path: '/api/finances' };
