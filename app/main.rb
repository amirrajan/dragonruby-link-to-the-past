require 'app/gtk_patches.rb'

class Game
  attr_gtk

  def defaults
    player.tile_size        = 64
    player.speed            = 3
    player.slash_frames     = 15
    player.x              ||= 50
    player.y              ||= 400
    player.dir_x          ||=  1
    player.dir_y          ||= -1
    player.is_moving      ||= false
    state.watch_list      ||= {}
    state.enemies         ||= []

    if state.tick_count == 0
      add_enemy
      state.show_watch_list   = true
    end
  end

  def add_enemy
    state.enemies << {
      x: 1200 * rand,
      y: 600 * rand,
      w: 64,
      h: 64,
      is_hit: false
    }
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
      flip_horizontally: player.dir_x > 0,
      # a: 40
    }
  end

  def horizontal_stand
    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-stand.png',
      flip_horizontally: player.dir_x > 0,
      # a: 40
    }
  end

  def horizontal_slash
    tile_index   = player.slash_at.frame_index(5, player.slash_frames / 5, false)
    tile_index ||= 0

    {
      x: player.x - 41.25,
      y: player.y - 41.25,
      w: 165,
      h: 165,
      path: 'sprites/horizontal-slash.png',
      tile_x: 0 + (tile_index * 128),
      tile_y: 0,
      tile_w: 128,
      tile_h: 128,
      flip_horizontally: player.dir_x > 0
    }
  end

  def render_player
    if player.slash_at
      outputs.sprites << horizontal_slash
    elsif player.is_moving
      outputs.sprites << horizontal_run
    else
      outputs.sprites << horizontal_stand
    end
  end

  def render_enemies
    outputs.solids << state.enemies.map do |e|
      if e[:is_hit]
        e.merge({ r: 255 })
      else
        e
      end
    end
  end

  def render_watch_list
    return if !state.show_watch_list
    outputs.labels << state.watch_list.map.with_index do |(k, v), i|
       [30, 710 - i * 28, "#{k}: #{v || "(nil)"}"]
    end

    outputs.borders << player.slash_collision_rect
  end

  def b_down?
    inputs.controller_one.key_down.a # classice usb gamepad: a button is actually the b button lol
  end

  def input
    # player movement
    if slash_completed? && (vector = inputs.directional_vector)
      player.x += vector.x * player.speed
      player.y += vector.y * player.speed
    end
    player.slash_at = b_down? if b_down?
    state.watch_list[:slash_at] = player.slash_at
  end

  def calc_movement
    # movement
    if vector = inputs.directional_vector
      state.debug_label = vector
      player.dir_x = vector.x
      player.dir_y = vector.y
      player.is_moving = true
    else
      state.debug_label = vector
      player.is_moving = false
    end

    state.watch_list[:dir_x] = player.dir_x
    state.watch_list[:is_moving] = player.is_moving
    state.watch_list[:directional_vector] = inputs.directional_vector
    state.watch_list[:location] = [player.x, player.y]
  end

  def calc_slash
    if slash_completed?
      player.slash_at = nil
    end

    if player.dir_x.pos?
      player.slash_collision_rect = [player.x + player.tile_size,
                                     player.y + player.tile_size.half - 10,
                                     40,
                                     20]
    else
      player.slash_collision_rect = [player.x - 32 - 8,
                                     player.y + player.tile_size.half - 10,
                                     40,
                                     20]
    end

    state.watch_list[:slash_elapsed] = !player.slash_at || player.slash_at.elapsed?(15)
    state.watch_list[:slash_can_damage] = slash_can_damage?

    if slash_can_damage?
      enemy_hit = false
      state.enemies.each do |e|
        if e.intersect_rect? player.slash_collision_rect
          e[:is_hit] = true
          enemy_hit = true
        end
      end

      state.enemies.reject! { |e| e[:is_hit] }

      add_enemy if enemy_hit
    end
  end

  def slash_completed?
    !player.slash_at || player.slash_at.elapsed?(player.slash_frames)
  end

  def slash_can_damage?
    !slash_completed? && (player.slash_at + player.slash_frames.idiv(2)) == state.tick_count
  end

  def calc
    calc_movement
    calc_slash
  end

  # source is at http://github.com/amirrajan/dragonruby-link-to-the-past
  def tick
    defaults
    render_enemies
    render_player
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

$gtk.reset
