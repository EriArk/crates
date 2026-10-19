# Save Journal

**Type:** Extension for TrainerOS  
**Status:** Selected concept, not implemented.

A readable history of game save backups, with safe restoration when available.

## Initial scope

- Browse existing verified save/backup history.
- Request supported recovery of an earlier version.

## Integration notes

All save changes must use TrainerOS protected host save transactions; never write raw saves behind its back.

**Next:** Discuss detailed UI, technical approach and scope later.

See [original idea notes](docs/idea.md).
