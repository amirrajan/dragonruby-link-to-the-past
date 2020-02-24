require 'app/gtk_patches.rb'
require 'app/tile.rb'

class Game
  attr_gtk

  def defaults
    state.show_debug_layer    = true if state.tick_count == 0
    assets.bush.w    = 52
    assets.bush.h    = 46
    assets.bush.path = 'sprites/bush.png'

    player.tile_size          = 64
    player.speed              = 3
    player.slash_frames       = 15
    player.x                ||= 50
    player.y                ||= 600
    player.dir_x            ||=  1
    player.dir_y            ||= -1
    player.is_moving        ||= false
    player.item.green_thumb ||= green_thumb_item
    state.watch_list        ||= {}
    state.bushes            ||= []
  end

  def green_thumb_item
    state.new_entity_strict(:bush) do |b|
      b.placement_locations = Tile.grid_tiles(assets.bush.w, assets.bush.h)
      b.aoe = nil
      b.cast_area = nil
    end
  end

  def add_bush point
    return if !point
    return if state.bushes.any? { |b| b[:x] == point.x && b[:y] == point.y }
    state.bushes << { x: point.x,
                      y: point.y,
                      w: assets.bush.w,
                      h: assets.bush.h,
                      path: assets.bush.path }
  end

  def sprite_horizontal_run
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
    }
  end

  def sprite_horizontal_stand
    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-stand.png',
      flip_horizontally: player.dir_x > 0,
    }
  end

  def sprite_horizontal_slash
    tile_index   = player.slash_at.frame_index(5, player.slash_frames.idiv(5), false) || 0

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
      outputs.sprites << sprite_horizontal_slash
    elsif player.is_moving
      outputs.sprites << sprite_horizontal_run
    else
      outputs.sprites << sprite_horizontal_stand
    end
  end

  def render_bushes
    outputs.sprites << state.bushes
  end

  def render_debug_layer
    return if !state.show_debug_layer
    outputs.debug << state.watch_list.map.with_index do |(k, v), i|
       [30, 710 - i * 28, "#{k}: #{v || "(nil)"}"].label
    end

    outputs.debug << player.slash_collision_rect.border
    outputs.debug << player.item.green_thumb.aoe.solid.merge(g: 200, w: 5, h: 5)
    outputs.debug << player.terrain_collision_body.border
  end

  def holding_green_thumb?
    inputs.controller_one.r1
  end

  def slash_initiate?
    # buffalo usb controller has a button and b button swapped lol
    inputs.controller_one.key_down.a || inputs.keyboard.key_down.j
  end

  def input
    input_move_player
    player.slash_at = slash_initiate? if slash_initiate?
  end

  def input_move_player
    player.is_moving = false
    return if !slash_complete?
    return unless vector = inputs.directional_vector
    player.is_moving = true
    player.dir_x = vector.x if !vector.x.zero?
    player.dir_y = vector.y if !vector.y.zero?
    vector.x = 0 if Tile.find_intersection(player_next_terrain_collision_body_x, state.bushes)
    vector.y = 0 if Tile.find_intersection(player_next_terrain_collision_body_y, state.bushes)
    player.x += vector.x * player.speed
    player.y += vector.y * player.speed
  end

  def calc_movement
    player.terrain_collision_body = [
      player.x + 15,
      player.y + 15,
      30,
      30
    ]
  end

  def calc_collision_boxes
    # re-calc the location of the swords collision box
    if player.dir_x.pos?
      player.slash_collision_rect = [player.x + player.tile_size + 8,
                                     player.y + player.tile_size.half - 10,
                                     20, 20]


      player.item.green_thumb.aoe = [player.x + player.tile_size + 27,
                                     player.y + player.tile_size.half - 10,
                                     1, 1]
    else
      player.slash_collision_rect = [player.x - 32,
                                     player.y + player.tile_size.half - 10,
                                     20, 20]

      player.item.green_thumb.aoe = [player.x - 36,
                                     player.y + player.tile_size.half - 10,
                                     1, 1]
    end

    player.item.green_thumb.cast_area = [player.x - (assets.bush.w * 3),
                                         player.y - (assets.bush.h * 3),
                                         assets.bush.w * 6, assets.bush.h * 6]

  end

  def calc_slash
    calc_collision_boxes

    # recalc sword's slash state
    player.slash_at = nil if slash_complete?

    # determine collision if the sword is at it's point of damaging
    return unless slash_can_damage?

    if holding_green_thumb?
      add_bush Tile.find_intersection(player.item.green_thumb.aoe,
                                      player.item.green_thumb.placement_locations)
    else
      state.bushes.delete Tile.find_intersection(player.slash_collision_rect,
                                                 state.bushes)
    end
  end

  def slash_complete?
    !player.slash_at || player.slash_at.elapsed?(player.slash_frames)
  end

  def slash_can_damage?
    # damage occurs half way into the slash animation
    return false if slash_complete?
    return false if (player.slash_at + player.slash_frames.idiv(2)) != state.tick_count
    return true
  end

  def calc
    # generate an enemy if there aren't any on the screen
    calc_movement
    calc_slash
  end

  def render_green_thumb
    return unless holding_green_thumb?
    outputs.borders << Tile.find_intersections(player.item.green_thumb.cast_area,
                                               player.item.green_thumb.placement_locations)
    outputs.solids  << Tile.find_intersection(
      player.item.green_thumb.aoe,
      player.item.green_thumb.placement_locations
    ).to_hash.merge(a: 128)
  end

  # source is at http://github.com/amirrajan/dragonruby-link-to-the-past
  def tick
    defaults
    render_bushes
    render_player
    render_green_thumb
    render_debug_layer
    outputs.labels << [30, 30, "Gamepad: D-Pad to move. B button to attack."]
    outputs.labels << [30, 52, "Keyboard: WASD/Arrow keys to move. J to attack."]
    input
    calc
  end

  def player
    state.player
  end

  def assets
    state.assets
  end

  def player_next_terrain_collision_body_x
    v_x, _ = inputs.directional_vector || [0, 0]
    player.terrain_collision_body.rect_shift_right(v_x * player.speed)
  end

  def player_next_terrain_collision_body_y
    _, v_y = inputs.directional_vector || [0, 0]
    player.terrain_collision_body.rect_shift_up(v_y * player.speed)
  end
end

$game = Game.new

def tick args
  $game.args = args
  $game.tick

  if args.inputs.controller_one.key_down.l1
    args.gtk.reset
    args.gtk.start_replay 'replays/regression.txt'
  end
end
