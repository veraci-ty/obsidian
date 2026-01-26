# Contributing to Obsidian

Thank you for your interest in contributing to Obsidian! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/veraci-ty/obsidian.git`
3. Create a branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites
- [Rojo](https://rojo.space/) for building
- Roblox Studio for testing
- A code editor with Luau support

### Building
```bash
rojo build -o Obsidian.rbxm default.project.json
```

## Code Style

- Use `--!strict` mode
- Follow Luau style conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

## Submitting Changes

1. Make your changes
2. Test thoroughly in Roblox Studio
3. Update documentation if needed
4. Commit with clear messages
5. Push to your fork
6. Open a Pull Request

## Pull Request Process

1. Ensure your code follows the style guidelines
2. Update documentation for any API changes
3. Add tests if applicable
4. Ensure all checks pass
5. Request review from maintainers

## Reporting Bugs

Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md) and include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details

## Feature Requests

Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md) and include:
- Clear description of the feature
- Motivation and use cases
- Proposed implementation (if you have ideas)

## Questions?

Feel free to open an issue for discussion or ask questions!
