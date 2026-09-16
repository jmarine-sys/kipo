-- `underlying_symbol` dejo de ser un dato informativo.
--
-- Nacio como "previsto, sin usar" (OD-17). ADR-024 lo dejo fuera de la cuenta
-- del rendimiento -medir al CCL no lo necesita- y eso sigue siendo cierto. Pero
-- ADR-025 le dio un segundo papel: es el simbolo con el que se le pide el precio
-- a la fuente. Un CEDEAR se llama "AAPL-CEDEAR" en tu libro y "AAPL" en BYMA.
--
-- La consecuencia incomoda: un CEDEAR sin este campo NO recibe precio automatico
-- y nada se rompe -simplemente se queda quieto, que es la peor forma de fallar-.
-- Por eso queda dicho en la base y no solo en un formulario.

comment on column instrument.underlying_symbol is
  'El simbolo del activo en la fuente de precios. Para un CEDEAR es la accion '
  'que representa (AAPL), que es como lo publica BYMA. Sin esto no hay precio '
  'automatico: ADR-025.';

comment on column instrument.ratio is
  'Cuantos CEDEARs equivalen a una accion. Informativo: ADR-024 mide al CCL, y '
  'esa division no necesita el ratio.';
