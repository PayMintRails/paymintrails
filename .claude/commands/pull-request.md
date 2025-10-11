# Claude Command: Pull Request

This command helps you create well-formatted pull requests.

## Creating a New Pull Request

1. First, prepare your PR description following the template in @.github/pull_request_template.md

2. Use the `gh pr create --draft` command to create a new pull request:

   ```bash
   # Create PR with proper template structure
   gh pr create --draft --title "type(scope): Your descriptive title" --body-file .github/pull_request_template.md --base main
   ```

## Best Practices

1. **Language**: Always use English for PR titles and descriptions

2. **PR Title Format**: Use the format `<type>(<scope>): <description>`  where type is one of:
    - `feat`: A new feature
    - `fix`: A bug fix
    - `docs`: Documentation changes
    - `style`: Code style changes (formatting, etc)
    - `refactor`: Code changes that neither fix bugs nor add features
    - `perf`: Performance improvements
    - `test`: Adding or fixing tests
    - `chore`: Changes to the build process, tools, etc.

  and scope is one of:
    - Use component names from file paths in the `crates/` subdirectory (cli, core, server, etc.)
    - Use general scopes like `deps`, `ci`, `docs` for broad changes
    - Omit scope if change affects multiple unrelated areas

  - **Present tense, imperative mood**: Write PR titles as commands (e.g., "add feature" not "added feature")
  - **Concise title**: Keep the PR title under 120 characters

3. **Description Template**: Always use our PR template structure from @.github/pull_request_template.md:

4. **Template Accuracy**: Ensure your PR description precisely follows the template structure:

  - Keep all section headers exactly as they appear in the template
  - Don't add custom sections that aren't in the template

5. **PR Description Format**:

  - Wrap at 100 characters
  - Explain **what** and **why**, not **how**

### Common Mistakes to Avoid

1. **Using Non-English Text**: All PR content must be in English
2. **Incorrect Section Headers**: Always use the exact section headers from the template
3. **Adding Custom Sections**: Stick to the sections defined in the template
4. **Using Outdated Templates**: Always refer to the current @.github/pull_request_template.md file

### Missing Sections

Always include all template sections, even if some are marked as "N/A" or "None"

## Related Documentation

- [PR Template](.github/pull_request_template.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub CLI documentation](https://cli.github.com/manual/)
