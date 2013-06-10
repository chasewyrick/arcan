--
-- Simple window helper class
--
-- Based around a central canvas (other vid or as it starts out,
-- a default colour) and a border, with optional bars that one can
-- add buttons to. 
-- 
--
-- table <= awbwnd_create(options)
-- possible options
--
local function awbwnd_show(self)
	show_image(self.anchor);
	resize_image(self.anchor, 0, 0);
	
	if (self.fullscreen) then
		move_image(self.anchor, 0, 0);
	else
		move_image(self.anchor, self.x, self.y); 
	end

	show_image(self.canvas);
	self:resize(self.width, self.height);
end

local function awbwnd_reorder(self, orderv)
	order_image({self.bordert, self.borderd, 
		self.borderl, self.borderr, self.canvas}, orderv);

	for key, val in pairs(self.directions) do
			val:reorder(orderv);
	end

	if (self.mode == "iconview") then
		for ind, val in ipairs(self.icons) do
			order_image({val.main, val.mainsel, val.label}, orderv);
		end
	end
end

local function awbwnd_hide(self)
	hide_image(self.root);
end

local function awbwnd_alloc(self)
	local bcol = settings.colourtable.dialog_border;
	local wcol = settings.colourtable.dialog_window;

	self.anchor = fill_surface(1, 1, 0, 0, 0);

--
-- we split the border into 4 objs to limit wasted fillrate,
-- only show if border is set to true (but alloc anyhow)
--
	self.bordert = fill_surface(1, 1, bcol.r, bcol.g, bcol.b);
	self.borderr = instance_image(self.bordert);
	show_image(self.borderr);
	self.borderl = instance_image(self.bordert);
	show_image(self.borderl);
	self.borderd = instance_image(self.bordert);
	show_image(self.borderd);
	link_image(self.bordert, self.anchor);

	if (self.border) then
		show_image(self.bordert);
	end

	self.resize_border = function(s)
		local bw = s.borderw;
		resize_image(s.bordert, s.width,           bw);
		resize_image(s.borderr, bw, s.height - bw * 2);
		resize_image(s.borderl, bw, s.height - bw * 2);
		resize_image(s.borderd, s.width,           bw);
		move_image(s.borderl, 0,            bw);
		move_image(s.borderr, s.width - bw, bw);
		move_image(s.borderd, 0, s.height - bw);
	end

	local cwidth  = self.width  - self.borderw * 2;
	local cheight = self.height - self.borderw * 2;
	local cx      = self.borderw;
	local cy      = self.borderw;

-- then check the different "bars" and resize / offset based on that

--
-- these need update triggers when we move etc. as they can't be directly
-- attached to the anchor due to instancing requirements, canvas is just
-- a placeholder, the :container(vid) method will do the rest 
--
	if (self.mode == "container") then
		self.canvas = fill_surface(cwidth, cheight, 0, 0, 0); 
		move_image(self.canvas, cx, cy);
		link_image(self.canvas, self.anchor);
		show_image(self.canvas);	

	elseif (self.mode == "container_managed") then
		self.canvas = fill_surface(1, 1, 0, 0, 0);

-- these require scrollbars
	elseif (self.mode == "iconview") then
		self.canvas = fill_surface(cwidth, cheight, wcol.r, wcol.g, wcol.b);
		move_image(self.canvas, cx, cy);
		link_image(self.canvas, self.anchor);
		show_image(self.canvas);

	elseif (self.mode == "listview") then
		self.canvas = fill_surface(cwidth, cheight, wcol.r, wcol.g, wcol.b);
		move_image(self.canvas, cx, cy); 
		link_image(self.canvas, self.anchor);
	end

	self:resize(self.width, self.height);
	return self;
end

local function awbwbar_refresh(self)
-- align against border while maintaining set "thickness"
	local bstep = self.parent.border and self.parent.borderw or 0;

	local bx = self.direction == "right" and 
		(self.parent.width - self.thickness - bstep) or bstep;
	local by = self.direction == "bottom" and 
		(self.parent.height - self.thickness - bstep) or bstep;

	move_image(self.activeid, bx, by);

-- then adjust based on other available bars, priority to top/bottom
	if (self.vertical) then
		local props  = image_surface_properties(self.parent.borderr, -1);
		
		if (self.parent.directions["top"]) then
			local thick = self.parent.directions["top"].thickness;
			move_image(self.root, 0, thick);
			props.height = props.height - thick; 
		end
		
		if (self.parent.directions["bottom"]) then
			props.height = props.height - self.parent.directions["bottom"].thickness;
		end

		resize_image(self.activeid, self.thickness, props.height);
	else
		local wbarw = image_surface_properties(self.parent.borderd, -1).width;
		wbarw = wbarw - self.parent.borderw * 2;	
		resize_image(self.activeid, wbarw, self.thickness);
	end

	link_image(self.activeid, self.root);
	image_mask_clear(self.activeid, MASK_OPACITY);
end

local function awbwnd_setwbar(dsttbl, active)
	if (dsttbl.activeid) then
		delete_image(dsttbl.activeid);
		dsttbl.activeid = nil;
	end

-- stretch and tile
	if (type(active) == "function") then
		dsttbl.activeid = active();
	else
		dsttbl.activeid = load_image(tostring(active));
		local props = image_surface_properties(dsttbl.activeid);
		switch_default_texmode(TEX_REPEAT, TEX_REPEAT, dsttbl.activeid);
		image_scale_txcos(dsttbl.activeid, dsttbl.parent.width / props.width, 1.0); 
	end

	show_image(dsttbl.activeid);
	dsttbl:refresh();
end

local function awbbar_own(self, vid)
	if (vid == self.activeid) then
		return self.direction;
	end

-- FIXME: sweep for buttons here
end

local function awbbar_reorder(self, order)
	if (valid_vid(self.activeid)) then
		order_image(self.activeid, order);
	end

-- FIXME: sweep for buttons, set order+1
end

local function awbwnd_resize(self, neww, newh)
	local minh_pad = 0;
	local minw_pad = 0;
	local cx = self.border and self.borderw or 0;
	local cy = self.border and self.borderw or 0;
	local cw = self.border and (neww - self.borderw * 2) or neww;
	local ch = self.border and (newh - self.borderw * 2) or newh;

	local left  = self.directions["left"  ];
	local right = self.directions["right" ];
	local top   = self.directions["top"   ];
	local bottom= self.directions["bottom"]; 

-- maintain constraints;
-- based on which bar-slots are available, make
-- sure that we accompany minimum thickness and height
-- and calculate final canvas contraints at the same time
	if (left) then
		minw_pad = minw_pad + left.thickness; 
		minh_pad = minh_pad + left.minheight;
		cx = cx + left.thickness;
		cw = cw - left.thickness;
	end

	if (right) then
		minw_pad = minw_pad + right.thickness;
		minh_pad = minh_pad + right.minheight;
		cw = cw - right.thickness;
	end

	if (top) then
		minh_pad = minh_pad + top.thickness;
		minw_pad = minw_pad + top.minheight;
		cy = cy + top.thickness;
		ch = ch - top.thickness;
	end

	if (bottom) then
		minh_pad = minh_pad + bottom.thickness;
		minw_pad = minw_pad + bottom.minwidth;
		ch = ch - bottom.thickness;
	end

	if (self.minw < minw_pad * 2) then
		self.minw = minw_pad * 2;
	end

	if (self.minh < minh_pad * 2) then
		self.minh = minh_pad * 2;
	end
 
	if (neww < self.minw) then
		neww = self.minw;
	end

	if (newh < self.minh) then
		newh = self.minh;
	end
	
	self.width  = neww;
	self.height = newh;

-- reposition / resize bars (and buttons)
	for key, val in pairs(self.directions) do
		val:refresh();
	end

	move_image(self.canvas, cx, cy);
	resize_image(self.canvas, cw, ch); 
-- reposition / rescale icons
	if (self.mode == "iconview") then
		self:refresh_icons();
	end	

	self:resize_border();
end

local function awbwnd_addbar(self, direction, active_resdescr, 
	inactive_resdescr, thickness)
	if (direction ~= "top" and direction ~= "bottom"
		and direction ~= "left" and direction ~= "right") or thickness < 1 then
		return false;
	end

	if (self.directions[direction]) then
		delete_image(self.directions[direction].root);
		if (valid_vid(self.directions[direction].state)) then
			delete_image(self.directions[direction].state);
		end
	end

	local newdir = {};
	newdir.root      = fill_surface(1, 1, 0, 0, 0);
	newdir.parent    = self;
	newdir.activeres = active_resdescr;
	newdir.inactvres = inactive_resdescr;
	newdir.thickness = thickness;
	newdir.minwidth  = 0;
	newdir.minheight = 0;
	newdir.refresh   = awbwbar_refresh;
	newdir.vertical  = direction == "left" or direction == "right";
	newdir.direction = direction;
	newdir.own       = awbbar_own;
	newdir.reorder   = awbbar_reorder;

	link_image(newdir.root, self.bordert);
	awbwnd_setwbar(newdir, newdir.activeres);

	self.directions[direction] = newdir;
	self:resize(self.width, self.height);

	return true;
end

local function awbwnd_newpos(self, newx, newy)
	if (self.fullscreen) then
		return;
	end

	move_image(self.anchor, newx, newy);
end

local function awbwnd_active(self, active)
	for key, val in pairs(self.directions) do
		local active_res = val.activeres;
		if (active == false and val.inactvres) then
			active_res = val.inactvres;
		end

		val.activestate = active;
		awbwnd_setwbar(val, active_res);
		self:reorder(ORDER_FOCUSWDW);
	end
end

-- 
-- only bars (and their buttons) and icons are clickable
--
local function awbwnd_own(self, vid)
	for ind, val in pairs(self.directions) do
		local res = val:own(vid);
		if (res) then
			return res;
		end 
	end

	if (self.mode == "iconview") then
		a = self:sample_icons();
		for key, val in ipairs(a) do	
			if (vid == val.active or vid == val.label) then
				return val;
			end
		end
	end

	if (vid == self.canvas) then
		return "canvas";
	end
end

--
-- Quite involved, based on desired icon layout, number of icons
-- and window mode, try to evenly divide the set of defined icons
-- across the available space
--
local function icons_poslbl(val, cx, cy, ralign, balign, order)
	local lprops = image_surface_properties(val.label );
	local sprops = image_surface_properties(val.active);

	if (ralign) then
		cx = cx - sprops.width;
	end

	if (balign) then
		cy = cy - lprops.height - sprops.height;
	end

	move_image(val.main, cx, cy);
	order_image({val.active, val.label}, order);
	show_image({val.active, val.label});

	return sprops.width, (lprops.height + sprops.height);
end

local function icons_halign(self, sx, sy, ex, ey, hstep, order)
	local cx_x = sx;
	local cx_y = sy;
	local iconset = self:sample_icons();
	local mwidth = 0;

	for i=1,#iconset do
		local lw, lh = icons_poslbl(iconset[i], cx_x, 
			cx_y, hstep == -1, false, order);
	
		if (lw > mwidth) then
			mwidth = lw;
		end

-- only calculate next coords if relevant
		if (i < #iconset) then
			local aprops = image_surface_properties(iconset[i+1].active, -1);
			local lprops = image_surface_properties(iconset[i+1].label,  -1);
		
			cx_y = cx_y + lh + self.spacing;
	
-- use next icon as basis for dimensions as they can have different sizes
-- padding is embedded in ex/ey, as is adding margins against borders
			if ( cx_y + aprops.height + lprops.height >= ey ) then
				cx_y = sy;
				cx_x = cx_x + (hstep * mwidth); 
				mwidth = 0;
	
				if ((hstep == 1 and cx_x >= ex) or
					(hstep == -1 and cx_x <= ex)) then
					break;
				end
			end
		
		end
	end

end

local function awbwnd_refreshicons(self)
	local cprops = image_surface_properties(self.canvas, -1);

	local mx = cprops.width - self.spacing;
	local my = cprops.height - self.spacing; 

	local orderv = cprops.order; 

--
-- just repetitions of the same theme / code,
-- merging them didn't bring much more compact code, but 
-- notably more messy 
--
	if (self.iconalign == "left") then
		icons_halign(self, self.spacing, self.spacing, mx, my, 1, orderv);

	elseif (self.iconalign == "right") then
		icons_halign(self, cprops.width, self.spacing, 0, my, -1, orderv);
	end
end

local function awbwnd_iconsoff(self)
	for ind, val in ipairs(self.icons) do
		val:forceoff();
	end
end

local function awbwnd_activeicon(self)
	local worder = image_surface_properties(self.active).order;
	local active = self.active == self.mainsel;

-- only allow one selected?
	if (self.parent.singleselect) then
		self.parent:iconsoff();
	end

	if (active) then
		self:forceoff();
		if (self.trigger) then
			self:trigger();
		end
	else
		self:forceon();
	end
end

local function awbwnd_selon(self)
	local order = image_surface_properties(self.parent.canvas).order;
	hide_image(self.main);
	show_image(self.mainsel);
	self.active = self.mainsel;
	order_image(self.mainsel, order);
end

local function awbwnd_seloff(self)
	if (self.active ~= self.mainsel) then
		return;
	end

	local order = image_surface_properties(self.parent.canvas).order;
	copy_image_transform(self.active, self.mainsel);
	hide_image(self.mainsel);
	show_image(self.main);
	order_image(self.main, order);
	self.active = self.main;
end

-- 
-- active refers current vid (main or main_sel if active)
-- mainsel and label are linked to main (but not sharing opacity)
-- we force mainsel and main to have the same properties
--
local function awbwnd_addicon(self, name, img, imga, font, fontsz, trigger)
	local newent   = {};
	newent.main    = type(img) == "string" and load_image(img)  or img;
	local mprops   = image_surface_properties(newent.main);

	newent.mainsel = type(img) == "string" and load_image(imga) or imga;
	resize_image(newent.mainsel, mprops.width, mprops.height);

	if (not (valid_vid(newent.main) and valid_vid(newent.mainsel))) then
		warning(string.format("awbwnd_addicon() couldn't add %s,%s to %s"),
			name, img, imga);
		return;
	end

	newent.active  = newent.main;
	newent.name    = name; 
	newent.trigger = trigger;
	newent.parent  = self;
	newent.toggle  = awbwnd_activeicon;
	newent.forceon = awbwnd_selon;
	newent.forceoff= awbwnd_seloff;
	newent.label   = render_text(string.format("\\f%s,%d %s", font, 
		fontsz, name));

	local lprops = image_surface_properties(newent.label);

	link_image(newent.main,    self.canvas);
	link_image(newent.mainsel, newent.main);
	link_image(newent.label,   newent.main);	

	image_clip_on(newent.main);
	image_clip_on(newent.mainsel);
	image_clip_on(newent.label);

	move_image(newent.label, math.floor(0.5 * (mprops.width 
	- lprops.width)), mprops.height); 
	image_mask_clear(newent.mainsel, MASK_OPACITY);
	image_mask_clear(newent.label,   MASK_OPACITY);

	table.insert(self.icons, newent);
end

--
-- replace in table to implement paging etc.
--
local function awbicons_sampleicons(self)
	local maxa = self.width * self.height * 4;
	local res = {};
	
	for ind, val in ipairs(self.icons) do
		local props = image_surface_properties(val.active);
		maxa = maxa - props.width * props.height; 
		table.insert(res, val);
		if (maxa < 0) then 
			break;
		end
	end

	return res;
end

--
-- Replacing the canvas vid is a bit complicated for 
-- Iconview / Listview since there's a bunch of other
-- things possibly anchored to it
--
local function awbwnd_canvas(self, newvid)
	if (self.mode == "container") then
		a = true;
	elseif (self.mode == "container_managed") then
		a = true;
	elseif (self.mode == "iconview" or 
		self.mode == "listview") then
		a = true;
	end
end

function awbwnd_destroy(self)
	delete_image(self.anchor);
end

function awbwnd_create(options)
	local restbl = {
		show    = awbwnd_show,
		hide    = awbwnd_hide,
		active  = awbwnd_active,
		add_bar = awbwnd_addbar, 
		resize  = awbwnd_resize,
		move    = awbwnd_newpos,
		own     = awbwnd_own,
		reorder = awbwnd_reorder,
		destroy = awbwnd_destroy,
		update_canvas = awbwnd_canvas,

-- static default properties
		mode = "container", -- {container, container_managed, iconview, listview} 
		fullscreen = false,
		border = true,
		borderw = 2,
		width = math.floor(VRESW * 0.3),
		height = math.floor(VRESH * 0.3),
		minw = 0,
		minh = 0,
		spacing = 12,
		activestate = true,

-- dynamic default properties
		x = 0, 
		y = 0,
		iconalign = "right",
		minimized = false,
		singleselect = true,
		directions = {}
	};

-- 
-- project the option table over the default
-- 
	if options ~= nil then 
		for key, val in pairs(options) do
			restbl[key] = val;
		end
	end

--
-- static controls for bad arguments
--
	if (restbl.mode ~= "iconview" and 
		restbl.mode ~= "container" and restbl.mode ~=
		restbl.mode ~= "container_managed") then
			warning("awbwnd_canvas(), bad mode in optionstable");
		return nil;
	end
 
	if (restbl.mode == "iconview") then
		restbl.add_icon = awbwnd_addicon;
		restbl.refresh_icons = awbwnd_refreshicons;
		restbl.sample_icons = awbicons_sampleicons;
		restbl.iconsoff = awbwnd_iconsoff;
		restbl.icons = {};
	end

	if (restbl.fullscreen) then
		restbl.width  = VRESW;
		restbl.height = VRESH;
		restbl.x = 0;
		restbl.y = 0;
	end

	restbl = awbwnd_alloc(restbl);
	return restbl;	
end
 