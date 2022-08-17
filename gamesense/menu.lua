local table_insert = table.insert;
local ui_set_visible, ui_set_callback, ui_get = ui.set_visible, ui.set_callback, ui.get;
local typeof = type;

local menu = {};

menu.callbacks = {};
menu.items = {};
menu.get = {};
menu.set_callback = function(rItem, fnCallback)
  if menu.callbacks[ rItem ] == nil then
    menu.callbacks[ rItem ] = {};
  end

  table_insert(menu.callbacks[ rItem ], fnCallback);

  local function fnCall(rItem)
    for _, value in ipairs(menu.callbacks[ rItem ]) do
      value(rItem);
    end
  end

  ui_set_callback(rItem, fnCall);
end
menu.update = function()
  for strTabName, tTab in pairs(menu.items) do

    for strItemName, tItem in pairs(tTab) do
      if tItem.m_callback == nil then
        goto continue
      end

      local fnVisibility = function()
        local bState = tItem.m_callback();

        ui_set_visible(tItem.m_var, bState);
        return bState
      end

      local bSuccess, strMsg = pcall(fnVisibility);
      if not bSuccess and _DEBUG then
        error(strMsg);
      end

      ::continue::
    end

    ::continue::
  end
end
menu.add = function(strTab, strName, rVar, tSettings)
  if menu.items[ strTab ] == nil then
    menu.items[ strTab ] = {};
    menu.get[ strTab ] = {};
  end

  if menu.items[ strTab ][ strName ] ~= nil then
    error('(!) menu::add / Not allowed to use already used name for menu elements:', strName);
  end

  local tItem = {};
  tItem.m_var = rVar;
  tItem.m_config = true;

  if tSettings ~= nil then
    if typeof(tSettings) ~= 'table' then
      goto continue
    end

    if typeof(tSettings.callback) ~= 'function' then
      tSettings.callback = function()
        return true
      end
    end

    if typeof(tSettings.config) == 'boolean' then
      tItem.m_config = tSettings.config;
    end

    ::continue::
  end
  
  tItem.m_callback = function()
    if not menu.master then
      return false
    end

    local bState = strTab == menu.tab;

    if not bState then
      return false
    end

    if tSettings ~= nil then
      if typeof(tSettings) ~= 'table' then
        goto continue
      end

      if typeof(tSettings.callback) == 'function' then
        return tSettings.callback()
      end

      ::continue::
    end

    return true
  end

  menu.items[ strTab ][ strName ] = tItem;

  local fnUpdate = function(rItem)
    pcall(function()
      local value = {ui_get(rItem)};

      if #value == 1 then
        value = value[ 1 ];
      end
  
      menu.get[ strTab ][ strName ] = value;
      menu.update();
  
      return value
    end);
  end

  local fnBind = function()
    menu.set_callback(rVar, fnUpdate);
    fnUpdate(rVar);
  end

  local bSuccess, strMsg = pcall(fnBind);

  if not bSuccess and _DEBUG then
    die('(!) menu::add /', strMsg);
  end

  return rVar
end
menu.set_visible = function(item, bool)
  if typeof(item) == 'table' then
    for key, value in pairs(item) do
      menu.set_visible(value, bool);
    end

    return
  end
  
  ui_set_visible(item, bool);
end

return menu