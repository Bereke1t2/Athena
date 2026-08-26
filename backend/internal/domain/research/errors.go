package research

import "errors"

var (
	ErrNotFound          = errors.New("research: not found")
	ErrInvalidInput      = errors.New("research: invalid input")
	ErrIdentityConflict  = errors.New("research: identifiers map to multiple existing papers")
)
