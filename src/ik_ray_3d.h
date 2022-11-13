/*************************************************************************/
/*  ik_ray_3d.h                                                          */
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

#ifndef IK_RAY_3D_H
#define IK_RAY_3D_H

#include "core/io/resource.h"
#include "core/math/vector3.h"

class IKRay3D : public RefCounted {
	GDCLASS(IKRay3D, RefCounted);

	Vector3 tta, ttb, ttc;
	Vector3 I, u, v, n, dir, w0;
	bool inUse = false;
	Vector3 m, at, bt, ct, pt;
	Vector3 bc, ca, ac;

	Vector3 point_1;
	Vector3 point_2;
	Vector3 working_vector;
	static constexpr int X = 0;
	static constexpr int Y = 1;
	static constexpr int Z = 2;

protected:
	static void _bind_methods();

public:
	IKRay3D();
	virtual ~IKRay3D() {}
	IKRay3D(Vector3 p_p1, Vector3 p_p2);
	virtual Vector3 heading();
	virtual void set_heading(Vector3 &p_new_head);

	/**
	 * Returns the scalar projection of the input vector on this
	 * ray. In other words, if this ray goes from (5, 0) to (10, 0),
	 * and the input vector is (7.5, 7), this function
	 * would output 0.5. Because that is amount the ray would need
	 * to be scaled by so that its tip is where the vector would project onto
	 * this ray.
	 * <p>
	 * Due to floating point errors, the intended properties of this function might
	 * not be entirely consistent with its output under summation.
	 * <p>
	 * To help spare programmer cognitive cycles debugging in such circumstances,
	 * the intended properties
	 * are listed for reference here (despite their being easily inferred).
	 * <p>
	 * 1. calling scaled_projection(someVector) should return the same value as
	 * calling
	 * scaled_projection(closestPointTo(someVector).
	 * 2. calling getMultipliedBy(scaled_projection(someVector)) should return the
	 * same
	 * vector as calling closestPointTo(someVector)
	 *
	 * @param p_input a vector to project onto this ray
	 */
	virtual real_t scaled_projection(const Vector3 &p_input);

	/**
	 * adds the specified length to the ray in both directions.
	 */
	virtual void elongate(real_t amt);

	/**
	 * @param ta the first vertex of a triangle on the plane
	 * @param tb the second vertex of a triangle on the plane
	 * @param tc the third vertex of a triangle on the plane
	 * @return the point where this ray intersects the plane specified by the
	 *         triangle ta,tb,tc.
	 */
	virtual Vector3 intersects_plane(Vector3 ta, Vector3 tb, Vector3 tc);

	/*
	 * Find where this ray intersects a sphere
	 *
	 * @param Vector3 the center of the sphere to test against.
	 *
	 * @param radius radius of the sphere
	 *
	 * @param S1 reference to variable in which the first intersection will be
	 * placed
	 *
	 * @param S2 reference to variable in which the second intersection will be
	 * placed
	 *
	 * @return number of intersections found;
	 */
	virtual int intersects_sphere(Vector3 sphereCenter, real_t radius, Vector3 &S1, Vector3 &S2);
	virtual void p1(Vector3 in);
	virtual void p2(Vector3 in);
	virtual Vector3 p2();
	virtual Vector3 p1();
	virtual int intersects_sphere(Vector3 rp1, Vector3 rp2, float radius, Vector3 &S1, Vector3 &S2);
	float triangle_area_2d(float x1, float y1, float x2, float y2, float x3, float y3);
	void barycentric(Vector3 a, Vector3 b, Vector3 c, Vector3 p, Vector3 &uvw);
	virtual Vector3 plane_intersect_test(Vector3 ta, Vector3 tb, Vector3 tc, Vector3 &uvw);
	operator String() const {
		return String(L"(") + this->point_1.x + L" ->  " + this->point_2.x + L") \n " + L"(" + this->point_1.y + L" ->  " + this->point_2.y + L") \n " + L"(" + this->point_1.z + L" ->  " + this->point_2.z + L") \n ";
	}
};

#endif // IK_RAY_3D_H