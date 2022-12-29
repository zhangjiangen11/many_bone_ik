/*************************************************************************/
/*  ik_kusudama.cpp                                                      */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2022 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2022 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#include "ik_kusudama.h"
#include "math/ik_node_3d.h"

void IKKusudama::_update_constraint() {
	update_tangent_radii();
	update_rotational_freedom();
}

void IKKusudama::update_tangent_radii() {
	for (int i = 0; i < limit_cones.size(); i++) {
		Ref<IKLimitCone> current = limit_cones[i];
		Ref<IKLimitCone> next;
		if (i < limit_cones.size() - 1) {
			next = limit_cones[i + 1];
		}
		Ref<IKLimitCone> cone = limit_cones[i];
		cone->update_tangent_handles(next);
	}
}

IKKusudama::IKKusudama(Ref<IKNode3D> to_set, Ref<IKNode3D> bone_direction, Ref<IKNode3D> limiting_axes, real_t cos_half_angle_dampen) {
	Vector<real_t> in_bounds = { 1 };
}

void IKKusudama::set_axial_limits(real_t min_angle, real_t in_range) {
	min_axial_angle = min_angle;//fmod(min_angle, Math_TAU);
	range_angle = in_range; //fmod(in_range, Math_TAU);
	Vector3 y_axis = Vector3(0.0f, 1.0f, 0.0f);
	Vector3 z_axis = Vector3(0.0f, 0.0f, 1.0f);
	twist_min_vec = IKKusudama::quaternion_axis_angle(y_axis, min_axial_angle).xform(z_axis);
	twist_center_vec = IKKusudama::quaternion_axis_angle(y_axis, range_angle / 2.0).xform(twist_min_vec);
	twist_center_rot = Quaternion(z_axis, twist_center_vec);
	twist_half_range_half_cos = cos(range_angle / 4.0);
	twist_max_vec = IKKusudama::quaternion_axis_angle(y_axis, range_angle).xform(twist_min_vec);
}

void IKKusudama::set_snap_to_twist_limit(Ref<IKNode3D> bone_direction, Ref<IKNode3D> to_set, Ref<IKNode3D> twist_axes, real_t p_dampening, real_t p_cos_half_dampen) {
	if (!is_axially_constrained()) {
		return;
	}
	// Create a temporary orientation representing the global Vector3(0, 0, 1) represents the middle of the allowable twist range in global space.	
	Quaternion global_twist_center = twist_axes->get_global_transform().basis.get_quaternion() * twist_center_rot;
	Quaternion align_rot = global_twist_center.inverse() * to_set->get_global_transform().basis.get_quaternion(); 
	Quaternion twist_rotation, swing_rotation; // Hold to_set's decomposed swing and twist away from global_twist_centers's global basis.
	IKKusudama::get_swing_twist(align_rot, Vector3(0.0, 1.0, 0.0), swing_rotation, twist_rotation);
	twist_rotation = IKBoneSegment::clamp_to_quadrance_angle(twist_rotation, twist_half_range_half_cos);
	Transform3D to_set_transform = to_set->get_transform();
	Quaternion parent_global_inverse = to_set->get_parent()->get_global_transform().basis.get_quaternion().inverse();
	Quaternion recomposition = swing_rotation * twist_rotation;
	Basis rotation_basis = Basis(parent_global_inverse * (global_twist_center * recomposition));
	to_set->set_transform(Transform3D(rotation_basis, to_set_transform.origin));
}

real_t IKKusudama::signed_angle_difference(real_t min_angle, real_t p_super) {
	real_t d = Math::fmod(Math::abs(min_angle - p_super), real_t(Math_TAU));
	real_t r = d > Math_PI ? Math_TAU - d : d;

	real_t sign = (min_angle - p_super >= 0 && min_angle - p_super <= real_t(Math_PI)) || (min_angle - p_super <= -real_t(Math_PI) && min_angle - p_super >= -real_t(Math_TAU)) ? real_t(1.0) : real_t(-1.0);
	r *= sign;
	return r;
}

real_t IKKusudama::_to_tau(real_t angle) {
	real_t result = angle;
	if (angle < 0) {
		result = (2 * Math_PI) + angle;
	}
	result = _mod(result, (Math_PI * 2.0f));
	return result;
}

void IKKusudama::add_limit_cone(Vector3 new_cone_local_point, double radius) {
	Ref<IKLimitCone> cone = Ref<IKLimitCone>(memnew(IKLimitCone(new_cone_local_point, radius, Ref<IKKusudama>(this))));
	limit_cones.push_back(cone);
}

void IKKusudama::remove_limit_cone(Ref<IKLimitCone> limitCone) {
	this->limit_cones.erase(limitCone);
}

real_t IKKusudama::_mod(real_t x, real_t y) {
	if (!Math::is_zero_approx(y) && !Math::is_zero_approx(x)) {
		real_t result = Math::fmod(x, y);
		if (result < 0.0f) {
			result += y;
		}
		return result;
	}
	return 0.0f;
}

real_t IKKusudama::get_min_axial_angle() {
	return min_axial_angle;
}

real_t IKKusudama::get_range_angle() {
	return range_angle;
}

bool IKKusudama::is_axially_constrained() {
	return axially_constrained;
}

bool IKKusudama::is_orientationally_constrained() {
	return orientationally_constrained;
}

void IKKusudama::disable_orientational_limits() {
	this->orientationally_constrained = false;
}

void IKKusudama::enable_orientational_limits() {
	this->orientationally_constrained = true;
}

void IKKusudama::toggle_orientational_limits() {
	this->orientationally_constrained = !this->orientationally_constrained;
}

void IKKusudama::disable_axial_limits() {
	this->axially_constrained = false;
}

void IKKusudama::enable_axial_limits() {
	this->axially_constrained = true;
}

void IKKusudama::toggle_axial_limits() {
	axially_constrained = !axially_constrained;
}

bool IKKusudama::is_enabled() {
	return axially_constrained || orientationally_constrained;
}

void IKKusudama::disable() {
	this->axially_constrained = false;
	this->orientationally_constrained = false;
}

void IKKusudama::enable() {
	this->axially_constrained = true;
	this->orientationally_constrained = true;
}

double IKKusudama::get_rotational_freedom() {
	// Computation is cached from the update_rotational_freedom function.
	// Please contribute back a better solution if you write a better way to calculate rotational freedom.
	return rotational_freedom;
}

void IKKusudama::update_rotational_freedom() {
	double axial_constrained_hyper_area = is_axially_constrained() ? (range_angle / Math_TAU) : 1;
	// A quick and dirty solution (should revisit).
	double total_limit_cone_surface_area_ratio = 0;
	for (int32_t cone_i = 0; cone_i < limit_cones.size(); cone_i++) {
		Ref<IKLimitCone> l = limit_cones[cone_i];
		total_limit_cone_surface_area_ratio += (l->get_radius() * 2) / Math_TAU;
	}
	rotational_freedom = axial_constrained_hyper_area * (is_orientationally_constrained() ? MIN(total_limit_cone_surface_area_ratio, 1) : 1);
}

TypedArray<IKLimitCone> IKKusudama::get_limit_cones() const {
	return limit_cones;
}

Vector3 IKKusudama::local_point_on_path_sequence(Vector3 in_point, Ref<IKNode3D> limiting_axes) {
	double closest_point_dot = 0;
	Vector3 point = limiting_axes->get_transform().xform(in_point);
	point.normalize();
	Vector3 result = point;

	if (limit_cones.size() == 1) {
		Ref<IKLimitCone> cone = limit_cones[0];
		result = cone->get_control_point();
	} else {
		for (int i = 0; i < limit_cones.size() - 1; i++) {
			Ref<IKLimitCone> next_cone = limit_cones[i + 1];
			Ref<IKLimitCone> cone = limit_cones[i];
			Vector3 closestPathPoint = cone->get_closest_path_point(next_cone, point);
			double closeDot = closestPathPoint.dot(point);
			if (closeDot > closest_point_dot) {
				result = closestPathPoint;
				closest_point_dot = closeDot;
			}
		}
	}

	return result;
}

/**
 * Given a point (in global coordinates), checks to see if a ray can be extended from the Kusudama's
 * origin to that point, such that the ray in the Kusudama's reference frame is within the range_angle allowed by the Kusudama's
 * coneLimits.
 * If such a ray exists, the original point is returned (the point is within the limits).
 * If it cannot exist, the tip of the ray within the kusudama's limits that would require the least rotation
 * to arrive at the input point is returned.
 * @param in_point the point to test.
 * @param in_bounds returns a number from -1 to 1 representing the point's distance from the boundary, 0 means the point is right on
 * the boundary, 1 means the point is within the boundary and on the path furthest from the boundary. any negative number means
 * the point is outside of the boundary, but does not signify anything about how far from the boundary the point is.
 * @return the original point, if it's in limits, or the closest point which is in limits.
 */
Vector3 IKKusudama::get_local_point_in_limits(Vector3 in_point, Vector<double> *in_bounds) {
	Vector3 point = in_point.normalized();
	real_t closest_cos = -2.0;
	in_bounds->write[0] = -1;
	Vector3 closest_collision_point = Vector3(NAN, NAN, NAN);
	// This is an exact check for being inside the bounds of each individual cone.
	for (int i = 0; i < limit_cones.size(); i++) {
		Ref<IKLimitCone> cone = limit_cones[i];
		Vector3 collision_point = cone->closest_to_cone(point, in_bounds);
		if (Math::is_nan(collision_point.x) || Math::is_nan(collision_point.y) || Math::is_nan(collision_point.z)) {
			in_bounds->write[0] = 1;
			return point;
		}
		real_t this_cos = collision_point.dot(point);
		if (Math::is_nan(closest_collision_point.x) || Math::is_nan(closest_collision_point.y) || Math::is_nan(closest_collision_point.z) || this_cos > closest_cos) {
			closest_collision_point = collision_point;
			closest_cos = this_cos;
		}
	}
	if ((*in_bounds)[0] == -1) {
		// Case where there are multiple cones and we're out of bounds of all cones.
		// Are we in the paths between the cones.
		for (int i = 0; i < limit_cones.size() - 1; i++) {
			Ref<IKLimitCone> currCone = limit_cones[i];
			Ref<IKLimitCone> nextCone = limit_cones[i + 1];
			Vector3 collision_point = currCone->get_on_great_tangent_triangle(nextCone, point);
			if (Math::is_nan(collision_point.x)) {
				continue;
			}
			real_t this_cos = collision_point.dot(point);
			if (Math::is_equal_approx(this_cos, real_t(1.0))) {
				in_bounds->write[0] = 1;
				return point;
			}
			if (this_cos > closest_cos) {
				closest_collision_point = collision_point;
				closest_cos = this_cos;
			}
		}
	}
	// Return the closest boundary point between cones.
	return closest_collision_point;
}

void IKKusudama::set_axes_to_orientation_snap(Ref<IKNode3D> bone_direction, Ref<IKNode3D> to_set, Ref<IKNode3D> limiting_axes, real_t p_dampening, real_t p_cos_half_angle_dampen) {
	Vector<double> in_bounds = { 1.0 };
	bone_ray->p1(limiting_axes->get_global_transform().origin);
	bone_ray->p2(bone_direction->get_global_transform().xform(Vector3(0.0, 1.0, 0.0)));
	Vector3 bone_tip = limiting_axes->to_local(bone_ray->p2());
	Vector3 in_limits = get_local_point_in_limits(bone_tip, &in_bounds);
	if (in_bounds[0] < 0 && !Math::is_nan(in_limits.x) && !Math::is_nan(in_limits.y) && !Math::is_nan(in_limits.z)) {
		constrained_ray->p1(bone_ray->p1());
		constrained_ray->p2(limiting_axes->to_global(in_limits));
		Quaternion rectified_rot = Quaternion(bone_ray->heading(), constrained_ray->heading());
		to_set->rotate_local_with_global(Basis(rectified_rot).orthonormalized());
	}
}

void IKKusudama::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_limit_cones"), &IKKusudama::get_limit_cones);
	ClassDB::bind_method(D_METHOD("set_limit_cones", "limit_cones"), &IKKusudama::set_limit_cones);
}

void IKKusudama::set_limit_cones(TypedArray<IKLimitCone> p_cones) {
	limit_cones = p_cones;
}

void IKKusudama::get_swing_twist(
		Quaternion p_rotation,
		Vector3 p_axis,
		Quaternion &r_swing,
		Quaternion &r_twist) {
	double d = p_axis.dot(Vector3(r_twist.x, r_twist.y, r_twist.z));
	r_twist = Quaternion(p_axis.x * d, p_axis.y * d, p_axis.z * d, r_twist.w).normalized();
	if (d < 0.0)  {
		r_twist *= -1.0;
	}
	r_twist = r_twist.inverse();
	r_swing = r_twist;
	r_swing = p_rotation * r_swing;
	r_swing.normalize();
}

real_t IKKusudama::get_current_twist_rotation(Ref<IKBone3D> bone_attached_to) {
	return 1.0f;
}

void IKKusudama::set_current_twist_rotation(Ref<IKBone3D> bone_attached_to, real_t p_rotation) {
}
