"""Run companion regression fixtures. Requires lupa with its Lua 5.1 module."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import json
root = Path(__file__).resolve().parents[1]
addon, tests = root / 'PadenCrates', root / 'tests/padencrates'
def load(runtime, ns, names):
    for name in names:
        runtime.execute((addon/name).read_text(encoding='utf8'), 'PadenCrates', ns)
def test(runtime, ns, name):
    return runtime.execute((tests/name).read_text(encoding='utf8'), 'PadenCrates', ns)
lua = LuaRuntime(unpack_returned_tuples=True); ns = lua.table()
load(lua, ns, ['Catalog.lua', 'Engine.lua', 'Adapter.lua'])
engine = test(lua, ns, 'engine.lua') + test(lua, ns, 'adapter.lua')
lua = LuaRuntime(unpack_returned_tuples=True); ns = lua.table()
test(lua, ns, 'runtime.lua')
load(lua, ns, ['Locales.lua', 'Catalog.lua', 'Engine.lua', 'Adapter.lua', 'Fill.lua',
               'Tooltip.lua', 'Shopping.lua', 'ShoppingUI.lua', 'Core.lua'])
runtime = ns.testRun()
lua = LuaRuntime(unpack_returned_tuples=True); ns = lua.table()
load(lua, ns, ['Catalog.lua', 'Engine.lua', 'Adapter.lua', 'Shopping.lua'])
shopping = test(lua, ns, 'shopping.lua')
print(json.dumps({'lua': '5.1', 'engine': engine, 'runtime': runtime, 'shopping': shopping,
                  'assertionsPassed': engine + runtime + shopping}))
