# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- Add clocked `APB_DV` interface for design verification.
- Define macros for assigning APB interfaces.
- Add read-only and read-write registers with APB interface.
- Add basic test infrastructure for APB modules.

### Changed
- Rename `APB_BUS` interface to `APB`, change its parameters to constants, and remove `in` and `out`
  modports.
- `apb_ro_regs`: Use of `addr_decode` module for indexing and change to structs.

## 0.1.0 - 2018-09-12
### Changed
- Open source release.

### Added
- Initial commit.
