SELECT setval(pg_get_serial_sequence('grammars', 'id'), COALESCE((SELECT MAX(id) FROM grammars), 1), true);
SELECT setval(pg_get_serial_sequence('grammar_meanings', 'id'), COALESCE((SELECT MAX(id) FROM grammar_meanings), 1), true);
SELECT setval(pg_get_serial_sequence('grammar_contexts', 'id'), COALESCE((SELECT MAX(id) FROM grammar_contexts), 1), true);
SELECT setval(pg_get_serial_sequence('grammar_examples', 'id'), COALESCE((SELECT MAX(id) FROM grammar_examples), 1), true);