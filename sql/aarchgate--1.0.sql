CREATE OR REPLACE FUNCTION aarchgate_filter(strategy text, data bytea)
RETURNS int8
AS 'MODULE_PATHNAME', 'aarchgate_filter'
LANGUAGE C STRICT;

COMMENT ON FUNCTION aarchgate_filter(text, bytea) IS
'Execute AarchGate vectorized filter logic on binary data.
Parameters:
  strategy - Logic strategy: ''simple'' or ''arbitrage''
  data - Binary data to filter (bytea)
Returns:
  Number of matching records';
