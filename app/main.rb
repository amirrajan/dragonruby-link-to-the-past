require 'app/gtk_patches.rb'

class Game
  attr_gtk

  def defaults
    player.tile_size   = 64
    player.speed       = 3
    player.x         ||= 640
    player.y         ||= 360
    player.dir_x     ||=  1
    player.dir_y     ||= -1
    player.is_moving ||= false
    state.watch_list       ||= {}
    state.show_watch_list    = true if state.tick_count == 0
  end

  def horizontal_run
    tile_index = 0.frame_index(6, 3, true)
    tile_index = 0 if !player.is_moving

    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-run.png',
      tile_x: 0 + (tile_index * player.tile_size),
      tile_y: 0,
      tile_w: player.tile_size,
      tile_h: player.tile_size,
      flip_horizontally: player.dir_x > 0
    }
  end

  def horizontal_stand
    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-stand.png',
      flip_horizontally: player.dir_x > 0
    }
  end

  def horizontal_slash
    tile_index   = player.slash_at.frame_index(5, 3, false)
    tile_index ||= 0

    {
      x: player.x,
      y: player.y,
      w: player.tile_size * 1.2,
      h: player.tile_size * 1.2,
      path: 'sprites/horizontal-slash.png',
      tile_x: 0 + (tile_index * 32),
      tile_y: 0,
      tile_w: 30,
      tile_h: 30,
      flip_horizontally: player.dir_x > 0
    }
  end

  def render
    if player.slash_at
      outputs.sprites << horizontal_slash
    elsif player.is_moving
      outputs.sprites << horizontal_run
    else
      outputs.sprites << horizontal_stand
    end
  end

  def render_watch_list
    return if !state.show_watch_list
    outputs.labels << state.watch_list.map.with_index do |(k, v), i|
       [30, 710 - i * 28, "#{k}: #{v || "(nil)"}"]
    end
  end

  def b_down?
    inputs.controller_one.key_down.a # classice usb gamepad: a button is actually the b button lol
  end

  def input
    # player movement
    if vector = inputs.directional_vector
      player.x += vector.x * player.speed
      player.y += vector.y * player.speed
    end
    player.slash_at = b_down? if b_down?
    state.watch_list[:slash_at] = player.slash_at
  end

  def calc
    if vector = inputs.directional_vector
      state.debug_label = vector
      player.dir_x = vector.x
      player.dir_y = vector.y
      player.is_moving = true
    else
      state.debug_label = vector
      player.is_moving = false
    end

    state.watch_list[:is_moving] = player.is_moving
    state.watch_list[:directional_vector] = inputs.directional_vector
    state.watch_list[:slash_elapsed] = !player.slash_at || player.slash_at.elapsed?(15)

    if player.slash_at && player.slash_at.elapsed?(15)
      player.slash_at = nil
    end
  end

  # source is at http://github.com/amirrajan/dragonruby-link-to-the-past
  def tick
    defaults
    render
    render_watch_list
    input
    calc
  end

  def player
    state.player
  end
end

$game = Game.new

def tick args
  $game.args = args
  $game.tick
end
