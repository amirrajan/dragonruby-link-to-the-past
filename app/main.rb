require 'app/gtk_patches.rb'

def defaults args
  args.state.player.speed   = 3
  args.state.player.x     ||= 640
  args.state.player.y     ||= 360
  args.state.debug_label  ||= ""
end

def input_up args
  args.inputs.controller_one.up
end

def input_down args
  args.inputs.controller_one.down
end

def input_right args
  args.inputs.controller_one.right
end

def input_left args
  args.inputs.controller_one.left
end

def render args
  args.outputs.solids << [args.state.player.x, args.state.player.y, 64, 64].anchor_rect(0.5, 0.5)
end

def render_debug args
  args.outputs.labels << [30, 30, "#{args.state.debug_label}"]
end

# consider adding to the engine
def directional_vector args
  lr, ud = [args.inputs.controller_one.left_right,
            args.inputs.controller_one.up_down]

  if    lr == 0     &&     ud == 0
    nil
  elsif lr.abs == 1 && ud.abs == 1
    [lr.half, ud.half]
  else
    [lr, ud]
  end
end

def input args
  dx, dy = directional_vector args
  if dx && dy
    args.state.player.y += dy * args.state.player.speed
    args.state.player.x += dx * args.state.player.speed
  end
  args.state.debug_label = "#{dx} #{dy}"
end

# source is at http://github.com/amirrajan/dragonruby-link-to-the-past
def tick args
  defaults args
  render args
  render_debug args
  input args
end
