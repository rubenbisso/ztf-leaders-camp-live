-- One-time backfill for the nation/province split. Run AFTER the schema
-- migration in schema.sql has added the three new columns.
--
-- Deliberately not part of schema.sql: this rewrites answers members already
-- gave, so it should be read and run knowingly rather than on every deploy.
-- It is idempotent, and spiritual_province_legacy keeps the original text, so
-- a row mapped wrongly can always be reclassified later.
--
-- Measured on 149 production rows: 68 answered with a nation, 49 map cleanly
-- to a province, 19 were blank, and 13 need a human decision. Those 13 are
-- left with a nation but no province, and are listed at the bottom.

-- 1. Nation. Everything that was answered belongs to Cameroon except Togo.
UPDATE accountability_returns
   SET spiritual_nation = CASE
         WHEN lower(trim(coalesce(spiritual_province_legacy,''))) = 'togo' THEN 'Togo'
         WHEN coalesce(spiritual_province_legacy,'') <> ''                 THEN 'Cameroon'
         ELSE NULL END
 WHERE spiritual_nation IS NULL;

-- 2. Province. Only spellings we are confident about. Anything else stays
--    NULL rather than being guessed into the wrong province.
UPDATE accountability_returns SET spiritual_province = CASE lower(trim(coalesce(spiritual_province_legacy,'')))
    WHEN 'qg' THEN 'QG' WHEN 'quartier general' THEN 'QG' WHEN 'cameroune qg' THEN 'QG'
    WHEN 'sanaga maritime' THEN 'Sanaga Maritime' WHEN 'sauaga martine cmr' THEN 'Sanaga Maritime'
    WHEN 'adamaoua' THEN 'Adamaoua'
    WHEN 'centre' THEN 'Centre' WHEN 'centre cameroun' THEN 'Centre'
    WHEN 'psu' THEN 'PSU'
    WHEN 'douala' THEN 'Daouala'
    WHEN 'kadey' THEN 'Kadei'
    WHEN 'moungo' THEN 'Moungo'
    WHEN 'ouest' THEN 'Ouest'
    WHEN 'sud' THEN 'Sud'
    WHEN 'est' THEN 'Est' WHEN 'de l''est' THEN 'Est'
    WHEN 'yaounde' THEN 'Yaounde' WHEN 'yaoundé' THEN 'Yaounde' WHEN 'de yaoundé' THEN 'Yaounde'
    WHEN 'extrême nord' THEN 'Extreme Nord' WHEN 'extreme nord' THEN 'Extreme Nord'
    WHEN 'south west' THEN 'Sud Ouest' WHEN 'southwest' THEN 'Sud Ouest'
    WHEN 'mbaabi' THEN 'Mbam'
    ELSE NULL END;

-- 3. Currency for amounts already on file. Everything collected so far is
--    Cameroon apart from the one Togo member; XAF and XOF are both "franc
--    CFA" but they are not the same currency.
UPDATE accountability_returns
   SET currency = CASE WHEN spiritual_nation = 'Togo' OR phone LIKE '228%' THEN 'XOF' ELSE 'XAF' END
 WHERE currency IS NULL
   AND (savings_amount IS NOT NULL OR debt_amount IS NOT NULL OR debt_reimbursed IS NOT NULL);

-- 4. What still needs a human. Littoral and Ngaoundere are administrative
--    regions rather than spiritual provinces; the PSU rows carry a campus
--    suffix the map does not have; PSN and "mega eglise" are unclear.
--    SELECT id, full_name, spiritual_province_legacy FROM accountability_returns
--     WHERE spiritual_nation IS NOT NULL AND spiritual_province IS NULL
--       AND lower(trim(spiritual_province_legacy)) NOT IN ('cameroun','cameroon','cameroune','togo');
