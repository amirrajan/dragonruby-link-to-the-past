require 'app/gtk_patches.rb'

def defaults args
  args.state.player.tile_size   = 64
  args.state.player.speed       = 3
  args.state.player.x         ||= 640
  args.state.player.y         ||= 360
  args.state.player.dir_x     ||=  1
  args.state.player.dir_y     ||= -1
  args.state.player.is_moving ||= false
  args.state.debug_label      ||= ""
end

def horizontal_run args
  tile_index = 0.frame_index(6, 3, true)
  tile_index = 0 if !args.state.player.is_moving

  {
    x: args.state.player.x,
    y: args.state.player.y,
    w: args.state.player.tile_size,
    h: args.state.player.tile_size,
    path: 'sprites/horizontal-run.png',
    tile_x: 0 + (tile_index * args.state.player.tile_size),
    tile_y: 0,
    tile_w: args.state.player.tile_size,
    tile_h: args.state.player.tile_size,
    flip_horizontally: args.state.player.dir_x > 0
  }
end

def horizontal_stand args
  {
    x: args.state.player.x,
    y: args.state.player.y,
    w: args.state.player.tile_size,
    h: args.state.player.tile_size,
    path: 'sprites/horizontal-stand.png',
    flip_horizontally: args.state.player.dir_x > 0
  }
end

def render args
  if args.state.player.is_moving
    args.outputs.sprites << horizontal_run(args)
  else
    args.outputs.sprites << horizontal_stand(args)
  end
end

def render_debug args
  args.outputs.labels << [30, 30, "#{args.state.debug_label}"]
end

def input args
  if vector = args.inputs.directional_vector
    args.state.player.x += vector.x * args.state.player.speed
    args.state.player.y += vector.y * args.state.player.speed
  end
end

def calc args
  if vector = args.inputs.directional_vector
    args.state.debug_label = vector
    args.state.player.dir_x = vector.x
    args.state.player.dir_y = vector.y
    args.state.player.is_moving = true
  else
    args.state.debug_label = vector
    args.state.player.is_moving = false
  end
end

# source is at http://github.com/amirrajan/dragonruby-link-to-the-past
def tick args
  defaults args
  render args
  render_debug args
  input args
  calc args
end
