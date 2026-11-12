"""Keep Godot Web viewport and input coordinates consistent under CSS rotation."""
from pathlib import Path
import sys


def patch_engine(path):
    path=Path(path)
    source=path.read_text()
    if 'EGG_LANDSCAPE_ROTATED' in source:
        return
    replacements = [
        ('computePosition:function(evt,rect){const canvas=GodotConfig.canvas;',
         'computePosition:function(evt,rect){const canvas=GodotConfig.canvas;if(globalThis.EGG_LANDSCAPE_ROTATED){return[(evt.clientY-rect.top)*canvas.width/rect.height,(rect.right-evt.clientX)*canvas.height/rect.width]}'),
        ('width=Math.floor(window.innerWidth*scale);height=Math.floor(window.innerHeight*scale)',
         'width=Math.floor((globalThis.EGG_LANDSCAPE_ROTATED?window.innerHeight:window.innerWidth)*scale);height=Math.floor((globalThis.EGG_LANDSCAPE_ROTATED?window.innerWidth:window.innerHeight)*scale)'),
        ('const rel_pos_x=evt.movementX*rw;const rel_pos_y=evt.movementY*rh;',
         'const rel_pos_x=globalThis.EGG_LANDSCAPE_ROTATED?evt.movementY*canvas.width/rect.height:evt.movementX*rw;const rel_pos_y=globalThis.EGG_LANDSCAPE_ROTATED?-evt.movementX*canvas.height/rect.width:evt.movementY*rh;'),
    ]
    for before,after in replacements:
        if source.count(before)!=1:
            raise RuntimeError('Godot Web template changed; inspect viewport/input adapter before exporting')
        source=source.replace(before,after)
    path.write_text(source)


if __name__=='__main__':
    patch_engine(sys.argv[1])
