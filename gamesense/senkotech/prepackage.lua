-- originals
local table_insert = table.insert;
local client_color_log, client_set_event_callback, client_delay_call = client.color_log, client.set_event_callback, client.delay_call;
local ui_set_callback, ui_set_visible, ui_update, ui_get, ui_set, ui_new_button = ui.set_callback, ui.set_visible, ui.update, ui.get, ui.set, ui.new_button;

-- defines
local f = string.format;
local typeof = type;

local message = function(r, g, b, ...)
  client_color_log(255, 255, 64, '[prepackage]\0');
  client_color_log(150, 150, 150, ' » \0');
  client_color_log(r, g, b, f(...));
end

local warning = function(...)
  message(255, 188, 0, ...);
end

local die = function(...)
  message(255, 128, 128, ...);
  error();
end

local hotkey_states = {
  [ 0 ] = 'Always on',
  'On hotkey',
  'Toggle',
  'Off hotkey',
};

-- globals
callback = {};
menu_mt = {};
menu = {};

-- workspace
callback.thread = 'main';
callback.history = {};
callback.get = function(key, result_only)
  local this = callback.history[ key ];

  if not this then
    return
  end

  if result_only then
    return unpack(this.m_result)
  end

  return this
end
callback.new = function(key, event_name, func)
  local this = {};
  this.m_key = key;
  this.m_event_name = event_name;
  this.m_func = func;
  this.m_result = {};

  local handler = function(...)
    callback.thread = event_name;
    this.m_result = {func(...)};
  end

  local protect = function(...)
    local success, result = pcall(handler, ...);

    if success then
      return
    end

    if isDebug then
      result = f('%s, debug info: key = %s, event_name = %s', result, key, event_name);
    end

    die('|!| callback::new - %s', result);
  end

  client_set_event_callback(event_name, protect);
  this.m_protect = protect;

  callback.history[ key ] = this;
  return this
end

menu_mt.register_callback = function(self, callback)
  if not callback then
    return false
  end

  if typeof(self) == 'table' then
    self = self.m_reference;
  end

  if not self then
    return false
  end

  if menu.binds[ self ] == nil then
    menu.binds[ self ] = {};

    local refresh = function(item)
      for k, v in ipairs(menu.binds[ self ]) do
        v(item);
      end
    end

    ui_set_callback(self, refresh);
  end

  table_insert(menu.binds[ self ], callback);
  return true
end
menu_mt.get = function(self, refresh)
  if not refresh then
    return unpack(self.m_value)
  end
  
  local protect = function()
    return {ui_get(self.m_reference)}
  end

  local success, result = pcall(protect);

  if not success then
    return
  end

  return unpack(result)
end
menu_mt.set = function(self, ...)
  if pcall(ui_set, self.m_reference, ...) then
    self.m_value = {self:get(true)};
  end
end
menu_mt.set_bypass = function(self, ...)
  local args = {...};

  client_delay_call(-1, function()
    self:set(unpack(args));
  end);
end
menu_mt.set_visible = function(self, value)
  if pcall(ui_set_visible, self.m_reference, value) then
    self.m_visible = value;
  end
end
menu_mt.update = function(self, ...)
  pcall(ui_update, self.m_reference, ...);
end
menu_mt.override = function(self, ...)
  pcall(menu.override, self.m_reference, ...);
end
menu_mt.add_as_parent = function(self, callback)
  self.m_parent = true;

  local this = {};
  this.original = self;
  this.callback = callback;

  table_insert(menu.parents, this);
  this.idx = #menu.parents;
end

menu.prod = {};
menu.binds = {};
menu.parents = {};
menu.updates = {};
menu.history = {};

menu.override = function(var, ...)
  if menu.history[ callback.thread ] == nil then
    menu.history[ callback.thread ] = {};
    
    local handler = function()
      local dir = menu.history[ callback.thread ];
      
      for k, v in pairs(dir) do
        if v.value == nil then      
          if v.backup ~= nil then
            ui_set(k, unpack(v.backup));
            menu.history[ callback.thread ][ k ] = nil;
          end
          
          goto skip
        end
        
        local value = {ui_get(k)};
        
        if v.backup == nil then
          v.backup = value;
            
          if typeof(v.backup) ~= 'table' then
            goto continue
          end
            
          if typeof(v.backup[ 1 ]) ~= 'boolean' then
            goto continue
          end
            
          if typeof(v.backup[ 2 ]) ~= 'number' then
            goto continue
          end
          
          v.backup = {hotkey_states[ v.backup[ 2 ] ]};
          ::continue::
        end
          
        ui_set(k, unpack(v.value));
        v.value = nil;
        ::skip::
      end
    end
    
    callback.new('menu::override::' .. callback.thread, callback.thread, handler);
  end
  
  local args = {...};
  
  if #args == 0 then
    return
  end
  
  if menu.history[ callback.thread ][ var ] == nil then
    menu.history[ callback.thread ][ var ] = {};
  end
  
  menu.history[ callback.thread ][ var ].value = args;
end
menu.set_visible = function(x, b)
  if typeof(x) == 'table' then
    for k, v in pairs(x) do
      menu.set_visible(v, b);
    end

    return
  end
  
  ui_set_visible(x, b);
end
menu.refresh = function()
  for k, v in pairs(menu.prod) do
    for x, y in pairs(v) do
      local protect = function()
        local state = true;
        
        if y.m_parameters.callback ~= nil then
          state = y.m_parameters.callback();
        end

        for k, v in pairs(menu.parents) do
          if y.m_parameters.bypass then
            if y.m_parameters.bypass[ k ] then
              goto continue
            end
          end

          if y == v.original then
            break
          end

          if not v.callback(y) then
            state = false;
            break
          end

          ::continue::
        end

        y:set_visible(state);
      end

      local isSuccess, output = pcall(protect);
  
      if isSuccess then
        goto continue
      end

      if isDebug then
        output = f('%s, debug info: group = %s, name = %s', output, y.m_group, y.m_name);
      end

      die('|!| menu::refresh - %s', output);
      ::continue::
    end
  end
end
menu.new = function(group, name, method, arguments, parameters)
  if menu.prod[ group ] == nil then
    menu.prod[ group ] = {};
  end

  if menu.prod[ group ][ name ] ~= nil then
    die('|!| menu::new - unable to create element with already used arguments: group = %s, name = %s', group, name);
  end

  local this = {};
  this.m_group      = group;
  this.m_name       = name;
  this.m_method     = method;
  this.m_arguments  = arguments;
  this.m_parameters = parameters or {};
  this.m_grouped    = menu.allow_group;
  this.m_visible    = true;
  
  setmetatable(this, {
    __index = menu_mt
  });

  local createReference = function()
    this.m_reference = this.m_method(unpack(this.m_arguments));
  end

  local isSuccess, output = pcall(createReference);
  
  if not isSuccess then
    if isDebug then
      output = f('%s, debug info: group = %s, name = %s', output, group, name);
    end

    die('|!| menu::new - %s', output);
  end

  menu.prod[ group ][ name ] = this;

  if this.m_method == ui_new_button then
    this:register_callback(this.m_arguments[ 4 ]);
  end

  local createCallback = function(item)
    local value = {ui_get(item)};
    this.m_value = value;
  end

  local protect = function(item)
    pcall(createCallback, item);
    menu.refresh();
  end

  this:register_callback(protect);
  protect(this.m_reference);

  if this.m_parameters.update_per_frame then
    table_insert(menu.updates, this);

    if not callback.get('menu::update_per_frame') then
      callback.new('menu::update_per_frame', 'paint_ui', function()
        for k, v in pairs(menu.updates) do
          if v:get(true) == v:get() then
            goto skip
          end

          v:set(v:get(true));
          menu.refresh();
          ::skip::
        end
      end);
    end
  end

  return this
end
menu.register_callback = menu_mt.register_callback;

callback.new('menu::shutdown', 'shutdown', function()
  for k, v in pairs(menu.history) do
    for x, y in pairs(v) do
      if y.backup == nil then
        goto skip
      end
      
      ui_set(x, unpack(y.backup));
      menu.history[ k ][ x ] = nil;
      ::skip::
    end
  end
end);
