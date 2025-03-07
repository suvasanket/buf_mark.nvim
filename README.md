# buf_mark.nvim
A simple mark based buffer navigation plugin inspired from harpoon.

## usage
Just mark a buffer with "M" followed by a char, then jump to the exact buffer with "'" followed by the char used to mark that buffer. Then we have `BufMarkDelete` cmd to delete specific marks and with a !(bang) you can delete every marks except persistant marks. We also have `BufMarkList` cmd which you can use to modify the marks(change, delete, swap).

Every marks are separated by projects and the behaviour of the jumping depends on which project's dir you are in.

## installation
lazy:
```lua
{
    "suvasanket/buf_mark.nvim",
    opts = {}
}
```

## config
default:
```lua
{
    mappings = {
        jump_key = "'",
        marker_key = "M",
    },
    persist_marks = { "a", "s", "d", "f" },
}
```
