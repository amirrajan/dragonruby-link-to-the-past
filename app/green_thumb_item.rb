module GreenThumbItem
  def add_bush point
    return if !point
    return if state.bushes.any? { |b| b[:x] == point.x && b[:y] == point.y }
    state.bushes << { x: point.x,
                      y: point.y,
                      w: assets.bush.w,
                      h: assets.bush.h,
                      path: assets.bush.path }
  end

  def green_thumb_item
    state.new_entity_strict(:bush) do |b|
      b.placement_locations = Tile.grid_tiles(assets.bush.w, assets.bush.h)
      b.aoe = []
      b.cast_area = nil
    end
  end

  def holding_green_thumb?
    inputs.controller_one.r1
  end

  def render_green_thumb
    return unless holding_green_thumb?
    outputs.sprites << Tile.find_intersections(player.item.green_thumb.cast_area,
                                               player.item.green_thumb.placement_locations).map {|t| t.merge(path: assets.bush.path, a: 80)}
    outputs.sprites  << Tile.find_intersection_in_many(
      player.item.green_thumb.aoe,
      player.item.green_thumb.placement_locations
    ).to_hash.merge(a: 128, path: assets.bush.path)
  end

  def calc_green_thumb_item
    # re-calc the location of the swords collision box
    if player.dir_x.pos?
      player.item.green_thumb.aoe = [
        [player.x + player.tile_size + 27,
         player.y + player.tile_size.half + 10,
         1, 1],
      ]
    else
      player.item.green_thumb.aoe = [
        [player.x - 36,
         player.y + player.tile_size.half + 10,
         1, 1],
      ]
    end

    player.item.green_thumb.cast_area = [player.x - (assets.bush.w),
                                         player.y - assets.bush.h * 1.5,
                                         assets.bush.w * 4, assets.bush.h * 4]

  end
end
