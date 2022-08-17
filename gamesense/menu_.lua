local typeof = type;
local ui_set_callback, ui_set_visible, ui_get, ui_set = ui.set_callback, ui.set_visible, ui.get, ui.set;
local table_insert = table.insert;
local f = string.format;

local menu_mt, menu = {}, {};

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
    self.m_value = {ui_get(self.m_reference)};
  end

  if not pcall(protect) then
    return
  end

  return unpack(self.m_value)
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

      die(
        const.exception_errors.protect_response,
        'menu::refresh',
        output
      );
      ::continue::
    end
  end
end
menu.new = function(group, name, method, arguments, parameters)
  if menu.prod[ group ] == nil then
    menu.prod[ group ] = {};
  end

  if menu.prod[ group ][ name ] ~= nil then
    die(
      const.exception_errors.already_used_keys,
      'menu::new',
      f('group = %s, name = %s', group, name)
    );
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

    die(
      const.exception_errors.protect_response,
      'menu::new',
      output
    );
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
    if callback.get('menu::update') == nil then
      table_insert(menu.updates, this);

      callback.register('menu::update', 'paint_ui', function()
        for k, v in pairs(menu.updates) do
          local value = v:get(true);
        
          if value == v:get() then
            return
          end
        
          v:set(value);
          menu.refresh();
        end
      end);
    end
  end

  return this
end
menu.register_callback = menu_mt.register_callback;

return menu_mt, menu
