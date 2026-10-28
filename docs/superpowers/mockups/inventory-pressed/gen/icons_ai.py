"""Placeholder item icons for the mockup, 16 art px each (shown at 64, like the user's icons).

Only Crude Scale and the equipment have real icons. These stand in for the extra consumables
the scale mockup shows and for the Refugee Camp Map. Mockup art: AI-made, not for the game.
"""
from PIL import Image


def _c(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


K = _c('2B1D14')
PALETTES = {
    'tea': {'k': K, 'w': _c('E6E2DA'), 'T': _c('8A5A2B'), 'C': _c('8DBF9A'), 'c': _c('C8E6CF'), 'D': _c('5E8F6E')},
    'vial': {'k': K, 'b': _c('8A5A2B'), 'g': _c('DCEBEE'), 'G': _c('A9C4CB'), 'L': _c('62A853'), 'l': _c('A5D98F')},
    'pill': {'k': K, 'w': _c('FFFFFF'), 'S': _c('C9D3DA'), 'D': _c('8A97A1')},
    'talisman': {'k': K, 'P': _c('F2DFA6'), 'p': _c('D9BF7E'), 'R': _c('B83A2E')},
    'gourd': {'k': K, 'b': _c('6B4A2A'), 'Y': _c('E2A845'), 'y': _c('F6D486'), 'O': _c('B0701F'), 'R': _c('B83A2E')},
    'capsule': {'k': K, 'I': _c('8C929C'), 'w': _c('D7DCE2'), 'H': _c('9E3B2E'), 'h': _c('C9604C')},
    'map': {'k': K, 'M': _c('EED9A8'), 'm': _c('C9A86A'), 'R': _c('B83A2E'), 'g': _c('5E8F4E')},
}

ROWS = {
    'tea': [
        '................',
        '.....w...w......',
        '....w...w.......',
        '.....w...w......',
        '................',
        '..kkkkkkkkkkk...',
        '.kTTTTTTTTTTTk..',
        '.kCCCCCCCCCCCkkk',
        '.kCcCCCCCCCCDk.k',
        '.kCcCCCCCCCCDk.k',
        '..kCcCCCCCCDkkk.',
        '..kCCCCCCCCDk...',
        '...kCCCCCCDk....',
        '....kkkkkkk.....',
        '..kkkkkkkkkkk...',
        '................',
    ],
    'vial': [
        '................',
        '......kkkk......',
        '......kbbk......',
        '......kbbk......',
        '.....kkkkkk.....',
        '......kggk......',
        '.....kgggGk.....',
        '....kgggggGk....',
        '...kgggggggGk...',
        '...kLLLLLLLGk...',
        '...kLlLLLLLGk...',
        '...kLlLLLLLGk...',
        '...kLLLLLLLGk...',
        '....kLLLLLGk....',
        '.....kkkkkk.....',
        '................',
    ],
    'pill': [
        '................',
        '................',
        '.....kkkkkk.....',
        '....kwwSSSSk....',
        '...kwwSSSSSSk...',
        '..kwSSSSSSSSDk..',
        '..kwSSSSSSSSDk..',
        '..kSSSSSSSSSDk..',
        '..kSSSSSSSSSDk..',
        '..kSSSSSSSSDDk..',
        '...kSSSSSSDDk...',
        '....kDDDDDDk....',
        '.....kkkkkk.....',
        '................',
        '................',
        '................',
    ],
    'talisman': [
        '.......kk.......',
        '.......kk.......',
        '.....kkkkkk.....',
        '.....kPPPPk.....',
        '.....kPRRPk.....',
        '.....kPPRPk.....',
        '.....kPRRPk.....',
        '.....kPPPPk.....',
        '.....kPRPRk.....',
        '.....kPRRRk.....',
        '.....kPPPRk.....',
        '.....kPPPPk.....',
        '.....kPRRPk.....',
        '.....kpPPpk.....',
        '.....kkkkkk.....',
        '................',
    ],
    'gourd': [
        '........kk......',
        '.......kbk......',
        '......kkkk......',
        '.....kYYYYk.....',
        '.....kYyYYk.....',
        '......kYYk......',
        '.....kRRRRk.....',
        '....kYYYYYYk....',
        '...kYyYYYYYOk...',
        '...kYyYYYYYOk...',
        '...kYYYYYYYOk...',
        '...kYYYYYYOOk...',
        '....kYYYYOOk....',
        '.....kkkkkk.....',
        '................',
        '................',
    ],
    'capsule': [
        '................',
        '................',
        '................',
        '................',
        '...kkkkkkkkkk...',
        '..kIwwIIHhhHHk..',
        '.kIwIIIIHhHHHHk.',
        '.kIIIIIIHHHHHHk.',
        '.kIIIIIIHHHHHHk.',
        '..kIIIIIHHHHHk..',
        '...kkkkkkkkkk...',
        '................',
        '................',
        '................',
        '................',
        '................',
    ],
    'map': [
        '................',
        '.kkkkkkkkkkkkkk.',
        'kMMMMMMMMMMMMMMk',
        'kMmMMMMMMMMMMmMk',
        'kMMRMMMMMMMMMMMk',
        'kMMMRMMMMgMMMMMk',
        'kMMMMRMMgggMMMMk',
        'kMMMMMRMMgMMMMMk',
        'kMMMMMMRMMMMMMMk',
        'kMMMMMMMRMMRMRMk',
        'kMMMMMMMMRMMRMMk',
        'kMMMMMMMMMMRMRMk',
        'kMmMMMMMMMMMMmMk',
        '.kkkkkkkkkkkkkk.',
        '................',
        '................',
    ],
}


def make(name, size=64):
    rows, pal = ROWS[name], PALETTES[name]
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                im.putpixel((x, y), pal[ch])
    return im.resize((size, size), Image.NEAREST)
