#ifndef MANY_BONE_IK_PLUGIN_H
#define MANY_BONE_IK_PLUGIN_H

#include "editor/plugins/node_3d_editor_gizmos.h"
#include "editor/editor_inspector.h"
#include "editor/plugins/node_3d_editor_plugin.h"
#include "modules/many_bone_ik/src/many_bone_ik_3d.h"
#include "editor/plugins/skeleton_3d_editor_plugin.h"

class ManyBoneIK3DEditorPlugin;
class ManyBoneIK3DEditor;
class EditorInspectorPluginManyBoneIK : public EditorInspectorPlugin {
	GDCLASS(EditorInspectorPluginManyBoneIK, EditorInspectorPlugin);

	friend class ManyBoneIK3DEditorPlugin;

	ManyBoneIK3DEditor *skel_editor = nullptr;

public:
	virtual bool can_handle(Object *p_object) override;
	virtual void parse_begin(Object *p_object) override;
};

class ManyBoneIK3DEditor : public VBoxContainer {
	GDCLASS(ManyBoneIK3DEditor, VBoxContainer);

	Tree *joint_tree = nullptr;

protected:
	void _notification(int p_what);
	ManyBoneIK3D *ik = nullptr;
	BoneId select_bone = -1;

public:
	ManyBoneIK3DEditor(EditorInspectorPluginManyBoneIK *e_plugin, ManyBoneIK3D *p_ik);
	void _update_properties();
	void update_joint_tree();
	void create_editors();
};

// For each bone show the widget for kusudamas
// Show one transform editor widget
// twist basis
// orientation basis
// directional basis
// Find special storage for the basis above.
// Beside the limit cone
// Add a coloured (blue?) indicator for pinned bones
class ManyBoneIK3DEditorPlugin : public EditorPlugin {
	GDCLASS(ManyBoneIK3DEditorPlugin, EditorPlugin);
	EditorInspectorPluginManyBoneIK *skeleton_plugin = nullptr;

public:
	virtual EditorPlugin::AfterGUIInput forward_3d_gui_input(Camera3D *p_camera, const Ref<InputEvent> &p_event) override;
	bool has_main_screen() const override;
	virtual bool handles(Object *p_object) const override;
	virtual String get_name() const override;
	ManyBoneIK3DEditorPlugin();
};

#endif