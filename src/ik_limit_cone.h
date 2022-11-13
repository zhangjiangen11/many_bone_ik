/*************************************************************************/
/*  ik_limit_cone.h                                                      */
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

#ifndef IK_LIMIT_CONE_H
#define IK_LIMIT_CONE_H

#include "core/io/resource.h"
#include "core/object/ref_counted.h"

#include "ik_bone_segment.h"
#include "ik_kusudama.h"
#include "ik_ray_3d.h"

class IKKusudama;
class IKLimitCone : public Resource {
	GDCLASS(IKLimitCone, Resource);
	void compute_triangles(Ref<IKLimitCone> p_next);
	static Quaternion quaternion_set_axis_angle(Vector3 axis, real_t angle);

	Vector3 control_point;
	Vector3 radial_point;

	// Radius stored as cosine to save on the acos call necessary for the angle between.
	double radius_cosine = 0;
	double radius = 0;
	Vector3 closest_cone(Ref<IKLimitCone> next, Vector3 input) const;
	void set_tangent_circle_radius_next(double rad);
	Ref<IKKusudama> parent_kusudama;

	Vector3 tangent_circle_center_next_1;
	Vector3 tangent_circle_center_next_2;
	double tangent_circle_radius_next = 0;
	double tangent_circle_radius_next_cos = 0;

	/**
	 * A triangle where the [1] is the tangent_circle_next_n, and [0] and [2]
	 * are the points at which the tangent circle intersects this IKLimitCone and the
	 * next IKLimitCone.
	 */
	Vector<Vector3> first_triangle_next = { Vector3(), Vector3(), Vector3() };
	Vector<Vector3> second_triangle_next = { Vector3(), Vector3(), Vector3() };


	/**
	 *
	 * @param next
	 * @param input
	 * @return null if the input point is already in bounds, or the point's rectified position
	 * if the point was out of bounds.
	 */
	Vector3 get_closest_collision(Ref<IKLimitCone> next, Vector3 input) const;

	/**
	 * Determines if a ray emanating from the origin to given point in local space
	 * lies within the path from this cone to the next cone. This function relies on
	 * an optimization trick for a performance boost, but the trick ruins everything
	 * if the input isn't normalized. So it is ABSOLUTELY VITAL
	 * that @param input have unit length in order for this function to work correctly.
	 * @param next
	 * @param input
	 * @return
	 */
	bool determine_if_in_bounds(Ref<IKLimitCone> next, Vector3 input) const;
	Vector3 get_on_path_sequence(Ref<IKLimitCone> next, Vector3 input) const;

	/**
	 * returns null if no rectification is required.
	 * @param next
	 * @param input
	 * @param in_bounds
	 * @return
	 */
	Vector3 closest_point_on_closest_cone(Ref<IKLimitCone> next, Vector3 input, Vector<double> &in_bounds) const;

	virtual double get_tangent_circle_radius_next_cos();
	static Vector3 get_orthogonal(Vector3 p_in);
protected:
	virtual double _get_radius();

	virtual double _get_radius_cosine();

public:
	virtual ~IKLimitCone() {}
	IKLimitCone();
	IKLimitCone(Vector3 &direction, double rad, Ref<IKKusudama> attached_to);
	void update_tangent_handles(Ref<IKLimitCone> p_next);
	void set_tangent_circle_center_next_1(Vector3 point);
	void set_tangent_circle_center_next_2(Vector3 point);
	/**
	 *
	 * @param next
	 * @param input
	 * @return null if inapplicable for rectification. the original point if in bounds, or the point rectified to the closest boundary on the path sequence
	 * between two cones if the point is out of bounds and applicable for rectification.
	 */
	Vector3 get_on_great_tangent_triangle(Ref<IKLimitCone> next, Vector3 input) const;
	virtual double get_tangent_circle_radius_next();
	virtual Vector3 get_tangent_circle_center_next_1();
	virtual Vector3 get_tangent_circle_center_next_2();
	/**
	 * returns null if no rectification is required.
	 * @param input
	 * @param in_bounds
	 * @return
	 */
	Vector3 closest_to_cone(Vector3 input, Vector<double> &in_bounds) const;
	Vector3 get_closest_path_point(Ref<IKLimitCone> next, Vector3 input) const;
	virtual Vector3 get_control_point() const;
	virtual void set_control_point(Vector3 p_control_point);
	virtual double get_radius() const;
	virtual double get_radius_cosine() const;
	virtual void set_radius(double radius);
};

#endif // IK_LIMIT_CONE_H