-- Undo 000009: detach children and remove seeded field nodes.
UPDATE topics t
SET parent_id = NULL
FROM topics f
WHERE t.parent_id = f.id AND f.kind = 'field';

DELETE FROM topics WHERE kind = 'field';
