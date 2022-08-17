-- originals
local o_client_set_event_callback = client.set_event_callback;

client.set_event_callback = function(event_name, ...)
  o_client_set_event_callback = client.set_event_callback;
end
