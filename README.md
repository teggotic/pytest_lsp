# Pytest LSP ![Crystal CI](https://github.com/teggotic/pytest_lsp/workflows/Crystal%20CI/badge.svg?branch=master)

LSP implementation for pytests in pure [Crystal](https://crystal-lang.org/)

## Usage

### with coc.nvim

- Download latest pytest_lsp from release page or build it yourself
- Add to the coc config (use `:CocConfig` to get there) file following lines
```json
"languageserver": {
    "pytest": {
        "command": "<path to downloaded or build executable>",
        "filetypes": ["python"],
    }
}
```
- write `:CocRestart` or restart vim to get it up and running

If you have any problems with this instalation process, please refer to [coc.nvim language server](https://github.com/neoclide/coc.nvim/wiki/Language-servers) guide.
If you think that the problem is in pytest_lsp itself, then feel free to open an issue

### with any other client

- You can write a basic LSP client extention for your editor, which should support `textSyncing` and `gotoImplementation`

## Roadmap

- [x] Support custom written fixtures
- [x] Support test functions
- [ ] Add command to list all fixtures | tests
- [ ] Add coc extention so one can install pytest_lsp by `:CocInstall` command

## Contributing

1. Fork it ( https://github.com/teggotic/pytest_lsp/fork )
2. Create your feature branch (git checkout -b feature/my_new_feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [teggotic](https://github.com/teggotic) Danylo Lapirov - creator, maintainer
