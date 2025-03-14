# buf_mark.nvim
A simple mark based buffer navigation plugin inspired from harpoon.

[shot 2025-03-09 at 4.49.13 PM.webm](https://github.com/user-attachments/assets/c5303007-da6b-46bd-9bef-23d4af9e721c)


## usage
Just mark a buffer with " M " followed by a char, then jump to the marked buffer with " ' " followed by the char used to mark that buffer. Then we have `BufMarkDelete` cmd to delete specific marks and with a !(bang) you can delete every marks except persistent marks. We also have `BufMarkList` cmd which you can use to modify the marks(change, delete, swap).

Every marks are separated by projects and the behavior of the jumping depends on which project's buffer you are in.

Press " '\<space\> " to quickly open the `BufMarkList`

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

    -- :EditBuffer (Not plugin-specific, but it's included here.)
    edit_buffer = true, -- its a combination of :e and :buffer and better
    edit_buffer_unmatch_behaviour = 'notify', -- |edit, buffer, notify|
}
```
