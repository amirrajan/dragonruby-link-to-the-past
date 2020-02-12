require 'app/gtk_patches.rb'

class Game
  attr_gtk

  def defaults
    state.player.tile_size   = 64
    state.player.speed       = 3
    state.player.x         ||= 640
    state.player.y         ||= 360
    state.player.dir_x     ||=  1
    state.player.dir_y     ||= -1
    state.player.is_moving ||= false
    state.watch_list       ||= {}
    state.show_watch_list    = true if state.tick_count == 0
  end

  def horizontal_run
    tile_index = 0.frame_index(6, 3, true)
    tile_index = 0 if !state.player.is_moving

    {
      x: state.player.x,
      y: state.player.y,
      w: state.player.tile_size,
      h: state.player.tile_size,
      path: 'sprites/horizontal-run.png',
      tile_x: 0 + (tile_index * state.player.tile_size),
      tile_y: 0,
      tile_w: state.player.tile_size,
      tile_h: state.player.tile_size,
      flip_horizontally: state.player.dir_x > 0
    }
  end

  def horizontal_stand
    {
      x: state.player.x,
      y: state.player.y,
      w: state.player.tile_size,
      h: state.player.tile_size,
      path: 'sprites/horizontal-stand.png',
      flip_horizontally: state.player.dir_x > 0
    }
  end

  def render
    if state.player.is_moving
      outputs.sprites << horizontal_run
    else
      outputs.sprites << horizontal_stand
    end
  end

  def render_watch_list
    return if !state.render_watch_list
    outputs.labels << state.watch_list.map.with_index do |(k, v), i|
       [30, 710 - i * 28, "#{k}: #{v || "(nil)"}"]
    end
  end

  def input
    if vector = inputs.directional_vector
      state.player.x += vector.x * state.player.speed
      state.player.y += vector.y * state.player.speed
    end
    state.watch_list[:player_location] = [state.player.x, state.player.y]
  end

  def calc
    if vector = inputs.directional_vector
      state.debug_label = vector
      state.player.dir_x = vector.x
      state.player.dir_y = vector.y
      state.player.is_moving = true
    else
      state.debug_label = vector
      state.player.is_moving = false
    end

    state.watch_list[:directional_vector] = inputs.directional_vector
  end

  # source is at http://github.com/amirrajan/dragonruby-link-to-the-past
  def tick
    defaults
    render
    render_watch_list
    input
    calc
  end
end

$game = Game.new

def tick args
  $game.args = args
  $game.tick
end
