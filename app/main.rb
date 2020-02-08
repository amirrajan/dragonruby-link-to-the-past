require 'app/gtk_patches.rb'

def defaults args
  args.state.player.speed       = 3
  args.state.player.x         ||= 640
  args.state.player.y         ||= 360
  args.state.player.dir_x     ||=  1
  args.state.player.dir_y     ||= -1
  args.state.player.is_moving ||= false
  args.state.debug_label      ||= ""
end

def player_sprite args, tile_index
  tile_index = 0 if !args.state.player.is_moving
  tile_size = 24

  {
    x: args.state.player.x,
    y: args.state.player.y,
    w: 64,
    h: 64,
    path: 'sprites/horizontal_run.png',
    tile_x: 0 + (tile_index * 24),
    tile_y: 0,
    tile_w: 24,
    tile_w: 24,
    flip_horizontally: args.state.player.dir_x > 0
  }
end

def render args
  args.outputs.labels << [30, 30, "Note: You must have a usb controller to play.", 255, 255, 255]
  args.outputs.static_background_color = [0, 0, 0]
  args.outputs.sprites << player_sprite(args, 0.frame_index(6, 3, true))
end

def render_debug args
  args.outputs.labels << [30, 30, "#{args.state.debug_label}", 255, 255, 255]
end

def input args
  if vector = args.inputs.controller_one.directional_vector
    args.state.player.x += vector.x * args.state.player.speed
    args.state.player.y += vector.y * args.state.player.speed
  end
end

def calc args
  if vector = args.inputs.controller_one.directional_vector
    args.state.player.dir_x = vector.x
    args.state.player.dir_y = vector.y
    args.state.player.is_moving = true
  else
    args.state.player.is_moving = false
  end
end

# source is at http://github.com/amirrajan/dragonruby-link-to-the-past
def tick args
  defaults args
  render args
  # render_debug args
  input args
  calc args
end
