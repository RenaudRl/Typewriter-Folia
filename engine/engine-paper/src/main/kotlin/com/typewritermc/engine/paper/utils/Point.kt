package com.typewritermc.engine.paper.utils

import com.github.retrooper.packetevents.protocol.particle.Particle
import com.github.retrooper.packetevents.protocol.particle.data.ParticleDustData
import com.github.retrooper.packetevents.protocol.particle.type.ParticleTypes
import com.github.retrooper.packetevents.protocol.world.Location
import com.github.retrooper.packetevents.util.Vector3d
import com.github.retrooper.packetevents.util.Vector3f
import com.github.retrooper.packetevents.util.Vector3i
import com.github.retrooper.packetevents.wrapper.play.server.WrapperPlayServerParticle
import com.github.shynixn.mccoroutine.folia.regionDispatcher
import com.typewritermc.core.utils.point.*
import com.typewritermc.core.utils.point.Vector
import com.typewritermc.engine.paper.extensions.packetevents.sendPacketTo
import com.typewritermc.engine.paper.plugin
import io.github.retrooper.packetevents.util.SpigotConversionUtil
import kotlinx.coroutines.withContext
import org.bukkit.Color
import org.bukkit.entity.Player
import java.util.*
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

fun org.bukkit.util.Vector.toVector(): Vector {
    return Vector(x, y, z)
}

fun Point<*>.toPacketVector3f() = Vector3f(x.toFloat(), y.toFloat(), z.toFloat())
fun Point<*>.toPacketVector3d() = Vector3d(x, y, z)
fun Point<*>.toPacketVector3i() = Vector3i(blockX, blockY, blockZ)
fun Point<*>.toBukkitVector(): org.bukkit.util.Vector = org.bukkit.util.Vector(x, y, z)

fun World.toBukkitWorld(): org.bukkit.World = server.getWorld(UUID.fromString(identifier))
    ?: throw IllegalArgumentException("Could not find world '$identifier' for location, and no default world available.")

fun org.bukkit.World.toWorld(): World = World(uid.toString())

fun <RWP> RWP.toBukkitLocation(): org.bukkit.Location where RWP : Point<RWP>, RWP : Rotatable<RWP>, RWP : WorldHolder<RWP> {
    return org.bukkit.Location(world.toBukkitWorld(), x, y, z, yaw, pitch)
}

/**
 * Finds the first walkable location below the current position.
 * 
 * WARNING: This function accesses block data and must be called from the region's tick thread.
 * For async contexts, use [firstWalkableLocationBelowAsync] instead.
 */
fun <RWP> RWP.firstWalkableLocationBelow(maxDepth: Int = 7): RWP? where RWP : Point<RWP>, RWP : Rotatable<RWP>, RWP : WorldHolder<RWP> {
    val location = toBukkitLocation()
    var max = maxDepth
    while (location.block.isPassable && max-- > 0) location.y--
    if (max == 0) return null
    return withY(location.y + 1)
}

/**
 * Finds the first walkable location below the current position.
 * 
 * This is the FOLIA-safe async version that uses the region dispatcher to ensure
 * block data is accessed from the correct region thread.
 * 
 * @param maxDepth The maximum number of blocks to check below the current position.
 * @return The first walkable location below, or null if no walkable location is found within maxDepth.
 */
suspend fun <RWP> RWP.firstWalkableLocationBelowAsync(maxDepth: Int = 7): RWP? where RWP : Point<RWP>, RWP : Rotatable<RWP>, RWP : WorldHolder<RWP> {
    val location = toBukkitLocation()
    return withContext(plugin.regionDispatcher(location)) {
        var max = maxDepth
        while (location.block.isPassable && max-- > 0) location.y--
        if (max == 0) null else withY(location.y + 1)
    }
}

fun <RP> RP.toPacketLocation(): Location where RP : Point<RP>, RP : Rotatable<RP> {
    return Location(x, y, z, yaw, pitch)
}

fun org.bukkit.Location.toPosition(): Position = Position(World(world.uid.toString()), x, y, z, yaw, pitch)
fun org.bukkit.Location.toPacketLocation(): Location = SpigotConversionUtil.fromBukkitLocation(this)
fun org.bukkit.Location.toCoordinate(): Coordinate = Coordinate(x, y, z, yaw, pitch)

fun <WP1, WP2> WP1.isInWorldRange(point: WP2, range: Double): Boolean
        where WP1 : Point<WP1>, WP1 : WorldHolder<WP1>, WP2 : Point<WP2>, WP2 : WorldHolder<WP2> {
    if (!isSameWorld(this.world, point.world)) return false
    return isInRange(point.x, point.y, point.z, range)
}

private fun isSameWorld(world1: World, world2: World): Boolean {
    if (world1.identifier == world2.identifier) return true

    val bukkitWorld1 = try {
        server.getWorld(UUID.fromString(world1.identifier))
    } catch (e: Exception) {
        null
    }

    val bukkitWorld2 = try {
        server.getWorld(UUID.fromString(world2.identifier))
    } catch (e: Exception) {
        null
    }

    if (bukkitWorld1 != null && bukkitWorld2 != null) {
        return bukkitWorld1.uid == bukkitWorld2.uid
    }

    val world1Name = bukkitWorld1?.name ?: world1.identifier
    val world2Name = bukkitWorld2?.name ?: world2.identifier

    val regex1 = try { world1Name.toRegex() } catch (e: Exception) { null }
    val regex2 = try { world2Name.toRegex() } catch (e: Exception) { null }

    return regex1?.matches(world2Name) == true || regex2?.matches(world1Name) == true || world1Name.equals(world2Name, true)
}

fun <RP> RP.toBukkitLocation(bukkitWorld: org.bukkit.World): org.bukkit.Location where RP : Point<RP>, RP : Rotatable<RP> {
    return org.bukkit.Location(bukkitWorld, x, y, z, yaw, pitch)
}

fun Location.toCoordinate(): Coordinate =
    Coordinate(x, y, z, yaw, pitch)

val Player.position: Position
    get() = location.toPosition()

fun <P> P.particleSphere(
    player: Player,
    radius: Double,
    color: Color,
    phiDivisions: Int = 16,
    thetaDivisions: Int = 8,
) where P : Point<P> {
    var phi = 0.0
    while (phi < Math.PI) {
        phi += Math.PI / phiDivisions
        var theta = 0.0
        while (theta < 2 * Math.PI) {
            theta += Math.PI / thetaDivisions
            val x = radius * sin(phi) * cos(theta)
            val y = radius * cos(phi)
            val z = radius * sin(phi) * sin(theta)

            WrapperPlayServerParticle(
                Particle(
                    ParticleTypes.DUST,
                    ParticleDustData(sqrt(radius / 3).toFloat(), color.toPacketColor())
                ),
                true,
                Vector3d(this.x + x, this.y + y, this.z + z),
                Vector3f.zero(),
                0f,
                1
            ) sendPacketTo player
        }
    }
}
