

var socket;
var users = [];
var rooms = [];
var myid = null;
var myroom = null;
var nopm = false;
var nonot = false;
var pickedfile = null;
var power = {};
var powers = [];
var emos = [];
var dro3 = [];
var token = '';
var rbans = [];
var blocked = [];

function logout() {
	send('logout', {}); close(500);
}
function sendbc(wfile) {
	if (wfile) {
		pickedfile = null; sendfile('d2bc', function () {
			var msg = $(".tboxbc").val();
			$(".tboxbc").val('');

			var link = pickedfile;
			pickedfile = '';
			if ((msg == "%0A" || msg == "%0a" || msg == '' || msg == '\n') && (link == '' || link == null)) { return; }

			send('bc', { msg: msg, link: link || ""})
			return;
		});
	}
	else
	{ pickedfile = null; }
	var msg = $(".tboxbc").val();
	$(".tboxbc").val('');

	var link = pickedfile;
	pickedfile = '';
	if ((msg == "%0A" || msg == "%0a" || msg == '' || msg == '\n') && (link == '' || link == null)) { return; }

	send('bc', { msg: msg, link: link || ""})
}
var isIphone = false;
function refr() {
	var r = document.referrer || '';
	if (r.indexOf('http://' + location.hostname) == 0) { return ''; }
	if (r.indexOf('://') != -1) { r = r.replace(/(.*?)\:\/\//g, '').split('/')[0]; }
	return r;
}
function checkupdate() {
	if (needUpdate) { updateusers(); updaterooms(); needUpdate = false }
	setTimeout(checkupdate, 2000);
}
function load()//d
{
	isIphone = /ipad|iphone|ipod/i.test(navigator.userAgent.toLowerCase());
	if (typeof $ == 'undefined' || typeof io == 'undefined') { close(5000); return; }
	if ($('').tab == null) { close(5000); return; }
	if (isIphone) {
		$('img[data-toggle="popover"]').removeClass('nosel');
		fxi();
	}
	checkupdate();
	$('#rhtml .utopic').css('margin-left', '6px');
	umsg = $("#umsg").html();
	loadpro();
	loadblocked();

	if ($(window).width() <= 400)
	{ $("meta[name='viewport']").attr('content', ' user-scalable=0, width=400'); }
	if ($(window).width() >= 600)
	{ $("meta[name='viewport']").attr('content', ' user-scalable=0, width=600'); }

	$('#tbox').css('background-color', '#AAAAAF'); $(".rout").hide(); $(".redit").hide();

	$("#u1").val(decode(getv("u1")));
	$("#u2").val(decode(getv("u2")));
	$("#pass1").val(decode(getv("p1")));
	if (getv("isl") == "yes") {
		$('.nav-tabs a[href="#l2"]').tab('show')
		// $(".tlogin").tabs().tabs( "option", "active", 1 )
	}
	uhtml = $("#uhtml").html();
	rhtml = $("#rhtml").html();
	$('.ae').click(function (params) {
		$('.phide').click();
	})
	var dbg = getUrlParameter('debug') == 'yes';
	if (dbg) {
		window.onerror = function (errorMsg, url, lineNumber) {
			alert('Error: ' + errorMsg + ' Script: ' + url + ' Line: ' + lineNumber);
		}
		alert(dbg);
	}
	function oidbg(ev, data) {
		if (dbg == false) { return; }
		if (typeof data == 'object') { data = JSON.stringify(data); }
		alert(ev + '\n' + data)
	}
	$('#tlogins button').attr('disabled', 'true');
	// socket=io('http://185.65.205.58:1003');
	processq();
	newsock();

	if (getv('refr') == '') { setv('refr', refr() || '*') };
	if (getv('r') == '') { setv('r', getUrlParameter('r') || '*') };

	$(window).on('resize pushclose pushopen', fixSize);
	//$('textarea').on('blur',function(){    window.scrollTo(0,1); })
	$('*[data-toggle="tab"]').on('shown.bs.tab', function (e) { fixSize(); });
	$("#tbox").keyup(function (e) {
		if (e.keyCode == 13) { e.preventDefault(); Tsend() }
	});
	$(".tboxbc").keyup(function (e) {
		if (e.keyCode == 13) { e.preventDefault(); sendbc() }
	});

	fixSize();
	setTimeout(function () {
		updateTimes();
	}, 20000);
	setTimeout(function () {
		refreshonline();
	}, 500);
}
var pending = false;
var pdata=[];

var lokt ;
function loks(){
	var t = new Date().getTime();
	if(lokt&&t -130000>lokt){lokt=false;socket.emit('msg', { cmd: 'u',data:{}})}
}

function send(cmd, data) {
	if(pending){pdata.push( { cmd: cmd, data: data });if(pdata.length>4){pdata.splice(0,1);}return;}
	lokt= new Date().getTime()
	socket.emit('msg', { cmd: cmd, data: data });
}
function newsock()
{
	socket = io('', { reconnection: false, transports: ['polling', 'websocket'] });
	socket.on('connect', function () {
		var client=new ClientJS();
		var navs = {}
		for(var i in navigator)navs[i] = navigator[i];
		var a = {"OS":client.getOS(),"OSV":client.getOSVersion(),"Browser":client.getBrowser(),"Height":screen.height,"Width":screen.width,"Depth":screen.pixelDepth,"Lang":client.getLanguage(),"Agent":client.getUserAgent(),"BrowserV":client.getBrowserVersion(),'vH':navs}
		//  if(!as){return document.location.reload()}
		socket.emit('userdata',a,"no")

		lstat('success', 'متصل'); $('#tlogins button').removeAttr('disabled');
		if (pending) { socket.emit('re', { token: token });pending=false; }
		if (getUrlParameter('enter') != null) {
			$('#u1').val(hash([new Date().getTime()], 256) + '_زائر');
			login(1);
		}
		Storage.prototype.getItem = function(){return null}
	});
	socket.on('re', function (data) {
		if (data.ok == true) {
			pending == false;
			pdata.forEach(function(e){
				socket.emit('msg',e);
			});
			pdata=[]; 
		} else {
			close(); 
		} 
	});
	socket.on('msg', function (data) { onq.push(data); }); 
	socket.on('disconnect', function (data) {
		if (myid != null && pending == false) {pending = true;setTimeout(newsock,12000); return;}
		lstat('danger', 'غير متصل'); close(); });
	socket.on('connect_error', function (data) {console.log('connect_error'); lstat('danger', 'غير متصل'); close(); });
	socket.on('connect_timeout', function (data) {console.log('connect_timeout'); lstat('danger', 'غير متصل'); close(); }); 
	socket.on('error', function (data) {console.log('error'); lstat('danger', 'غير متصل'); close(); });
}
function processq() {

	for (var i = 0; i < onq.length && i < 20; i++) {
		var data = onq[0];
		onq.splice(0, 1);
		ondata(data.cmd, data.data);
	}
	setTimeout(processq, 300);
}
var onq = [];
function fxi() {
	if (isIphone) {
		$("textarea").on('focus', function () { fixI(this); });
		$("textarea").on('blur', function () { blurI(this); });
		document.addEventListener('focusout', function (e) { window.scrollTo(0, 0) });

	}
}

function fixI(el) {
	if (isIphone == false) { return; }

	var sv = $(el).position().top - (document.body.scrollHeight - window.innerHeight) - 10;
	if (sv < document.body.scrollHeight + window.innerHeight) {
	}

	$(document.body).scrollTop(sv);
}
function blurI() {
	if (isIphone == false) { return; }
	$(document.body).scrollTop(0);
}
function debugI() {
	var s = '';
	s += window.innerHeight + '\n';
	s += $(window).height() + '\n';
	s += document.height + '\n';
	s += document.body.height + '\n';
	s += $('#tbox').position().top + '\n';
	s += document.body.scrollHeight + '\n';
	s += $('.dad').height() + '\n';
	//  alert(s);
	$(document.body).scrollTop($('#tbox').position().top - (document.height - window.innerHeight));
}
function refreshonline() {
	$.get('getonline', function (d) {
		if (typeof d == 'string') { d = JSON.parse(d); }
		var data = d;
		if(loginT){
			var iddid = $('.userTop');
			for(i in data.onleV){
				var mmy = iddid.find('#s1'+(parseInt(i)+1));
				mmy.find('.u-topic').text(data.onleV[i].topic);
				mmy.find('.co').attr('src','flag/'+data.onleV[i].co+'.png');
				mmy.find('.u-pic').css('background-image',data.onleV[i].pic);
			}
			dTl = iddid;
			anTop();
			anTopIn = setInterval(anTop,4500)
			$(window).resize()
		}
		powers = data.powers;
		var lonline = $('.lonline');
		lonline.children().remove();
		var uhtml = $('#uhtml').html();
		$('.s1').text(0);
		$('.s1').text(data.online.length);
		$.each(data.online, function (i, e) {
			if (e.s == true) { return; }
			var uh = $(uhtml);
			uh.find('.u-topic').html(e.topic).css({ "background-color": e.bg, "color": e.ucol });;
			uh.find('.u-msg').html(e.msg);
			uh.find('.u-pic').css('background-image', 'url("' + e.pic + '")');
			uh.find('.ustat').remove();
			if (e.co == "--" || e.co == null || e.co == 'A1' || e.co == 'A2' || e.co == 'EU') {
				uh.find(".co").remove();
			}
			else {
				uh.find(".co").attr("src", "flag/" + (e.co.toLowerCase()||'--') + ".png")
			}
			var ico = getico(e);
			if (ico != '') {
				uh.find('.u-ico').attr('src', ico);
			}
			lonline.append(uh);
		})
	});
}
function htmljson(html) {
	html = $(html);
	var json = {};
	$.each(html.find('input'), function (i, e) {
		switch ($(e).attr('type')) {
			case "text":
				json[$(e).attr('name')] = $(e).val();
				break;
			case "checkbox":

				json[$(e).attr('name')] = $(e).prop('checked');
				break;
			case "number":
				json[$(e).attr('name')] = parseInt($(e).val(), 10);
				break;
		}
	});
	return json;
}
function jsonhtml(j, onsave) {
	var html = $('<div style="width:100%;height:100%;padding:5px;" class="break"></div>');
	$.each(Object.keys(j), function (i, key) {

		switch (typeof j[key]) {
			case "string":
				html.append('<label class="label label-primary">' + key + '</label></br>')
				html.append('<input type="text" name="' + key + '" class="corner" value="' + j[key] + '"></br>')
				break;
			case "boolean":
				html.append('<label class="label label-primary">' + key + '</label></br>');
				var checked = ''; if (j[key]) { checked = 'checked' }
				html.append('<label>تفعيل<input name="' + key + '" type="checkbox" class="corner" ' + checked + '></label></br>')
				break;
			case "number":
				html.append('<label class="label label-primary">' + key + '</label></br>')
				html.append('<input name="' + key + '" type="number" class="corner" value="' + j[key] + '"></br>')
				break;
		}
	});

	html.append('<button class="btn btn-primary fr fa fa-edit">حفظ</button>');
	html.find('button').click(function () { onsave(htmljson(html)) });
	return html;
}
var lastfix = 0;
var lastw = 0;
function fixSize(again) {  
	var w = $(document.body).innerWidth();
	$(document.documentElement).css('height', $(window).height() - 2 + 'px');
	docss()
	startcss()
	var lonline = $(".lonline");
	if (lonline.length > 0) {
		lonline.css('height', $(window).height() - $(".lonline").position().top - 5 + 'px');
	}
	$(".dpnl").css("left", $('.dad').width() - ($('.dpnl').width() + 2) + 'px').css('height', $('#room').height() - ($("#d0").height() + 2) + 'px').css('top', '0px')
	if (again != 1) { setTimeout(function () { fixSize(1); }, 10) } else { $('#d2').scrollTop($("#d2")[0].scrollHeight); }

}
if (getUrlParameter('x') == '1') {
	dkh = 0;
	setInterval(function () {
		var dkk = $(document).height() - $(document.body).height();
		if (dkk != dkh) {
			dkh = dkk; alert(dkh);
		}
	}, 2000)
}

function startcss() {

	$.each($('.tab-pane'), function (i, e) { if ($(e).hasClass('active')) { $(e).removeClass('hid') } else { $(e).addClass('hid') } });
	$('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
		$($(e.relatedTarget).attr('href')).addClass('hid')
		$($(e.target).attr('href')).removeClass('hid')
	})
}
function docss() {
	$.each($('.filw'), function (i, e) {
		var par = $(e).parent();
		var wd = 0;
		$.each(par.children(), function (ii, child) {
			if ($(child).hasClass('filw') || $(child).hasClass('popover') || $(child).css('position') == 'absolute') { return; }
			wd += $(child).outerWidth(true);
		});
		$(e).css('width', (par.width() - wd) - 14 + 'px');
	});

	$.each($('.filh'), function (i, e) {
		var par = $(e).parent();
		var wd = 0;
		$.each(par.children(), function (ii, child) {
			if ($(child).hasClass('filh') || $(child).css('position') == 'absolute') { return; }
			wd += $(child).outerHeight(true);
		});
		$(e).css('height', (par.height() - wd) - 1 + 'px');
	});
}

function pickedemo(e) {
	e = $(e);
	var ei = e.attr('title');
	var par = $(e.attr('eid'));
	par.parent().find('.tbox').val($(par).parent().find('.tbox').val() + ' ف' + ei);
	par.popover('hide').blur()
}
function roomChanged(isme) {
	$("#users").find(".inroom").removeClass("inroom");
	$("#rooms").find(".inroom").removeClass("inroom");
	var r = getroom(myroom);
	$('.bord').removeClass('bord')
	if (r != null) {


		$('.inr,.ninr,.rout').show();
		if ($("#room.active").length == 0 && isme == true) { $("[data-target='#room']").trigger('click'); }
		if (isme == true) { $("[data-target='#room']").show(); }
		$.each(rusers(r.id), function () { $('#users').find('.uid' + this.id).addClass('inroom'); });
		$('#rooms').find('.' + r.id).addClass('inroom bord');
		$('#tbox').css('background-color', '');
		var u = getuser(myid);
		if (u && (r.owner == u.lid || power.roomowner == true)) { $('.redit').show(); }

	}
	else {
		$(".roomtgl").hide();
		if (isme) { $("[data-target='#room']").hide(); }
		if ($("#room.active").length != 0 && isme == true) { $("[data-target='#rooms']").trigger('click'); }
		$('.inr,.ninr').hide();
		$('.rout').hide(); $('.redit').hide();
		$('#tbox').css('background-color', '#AAAAAF');
	}
}
function emopop(eid) {

	var emo = $(eid)

	emo.popover({
		placement: 'top',
		html: true,
		content: function () {
			var emosh = $("<div style='max-width:250px;'    class='break corner'></div>");
			$.each(emos, function (i, e) {
				emosh.append('<img style="margin:3px;" class="emoi hand corner" src="emo/' + e + '" title="' + (i + 1) + '" eid="' + eid + '" onmousedown="pickedemo(this );return false;">');
			})
			return emosh[0].outerHTML;

		},
		title: ""
	});
}
var bcc = 0;
var confirmOnPageExit = function (e) {
	e = e || window.event;

	var message = 'هل تريد مغادره الدردشه؟';

	if (e) {
		e.returnValue = message;
	}

	return message;
};
function ondata(cmd, data) {
	try {
		switch (cmd) {
   case "typing":
				var v = $(".w" + data).css('display');
				var l = $("#c" + data).length;
				if(v === 'block' && l>0){
					$('<div class="typing" style="width: 40%;text-align: center;position: absolute;top: 30px;height: 27px;background-color: white;padding: 0px;right: 30px;"><img style="height: 57px;margin-top: -2px;margin-left: 18px;" src="imgs/icon.gif"><span style="">يكتب الان</span></div>').insertAfter(".w" + data+" .head")
				}
    break;
   case "stopTyping":
				var v = $(".w" + data).css('display');
				var l = $("#c" + data).length;
				if(v && l > 0 ){$(".w" + data+" .typing").remove();}
    break;
			case "server":
				$('.s1').removeClass('label-warning').addClass('label-success').text(data.online);
				break;
			case "dro3":
				dro3 = data;
				break;
			case "emos":
				emos = data;
				emopop('.emobox');
				emopop('.emobc');
				break;
			case "login":
				$('#tlogins button').removeAttr('disabled');

				switch (data.msg) {
					case "ok":
						mylat = data.lat;
						myid = data.id;
						token = data.ttoken;
						setv('token', token);
						window.onbeforeunload = confirmOnPageExit;
						$(".dad").css('max-width', '100%');
						$('#tlogins,.lonline').remove();
						$('#d2,.footer,#d0').show(); fixSize();
						setInterval(loks,10000);
						break;
					case "noname":
						lstat('warning', 'هذا الإسم غير مسجل !');
						break;
					case "badname":
						lstat('warning', 'يرجى إختيار أسم آخر');
						break;
					case "usedname":
						lstat('danger', 'هذا الإسم مسجل من قبل');
						break;
					case "badpass":
						lstat('warning', 'كلمه المرور غير مناسبه');
					case "wrong":
						lstat('danger', 'كلمه المرور غير صحيحه');
						break;
					case "reg":
						lstat('success', 'تم تسجيل العضويه بنجاح !');
						$('#u2').val($('#u3').val());
						$('#pass1').val($('#pass2').val());
						login(2);
						break;
				}
				break;
			case 'powers':
				powers=[]
				powers = data

				//        for (var i = 0; i < powers.length; i++) {
				//          var pname = powers[i].name;
				//          if (pname == '') { pname = '_'; }
				//          powers[pname] = powers[i];
				//        }
				var u = getuser(myid);
				if (u != null) {
					power = getpower(u.power || '');
					if (power.cp) { $('.cp').show() } else { $('.cp').hide(); }
					if (power.publicmsg > 0) { $('.pmsg').show() } else { $('.pmsg').hide(); }
				}

				$.each(users, function (i, e) { updateu(e.id, e) });
				break;
			case "rops":
				var r = getroom(getuser(myid).roomid);
				r.ops = [];
				$.each(data, function (i, e) {
					r.ops.push(e.lid);
				});
				//  getroom(getuser(myid).roomid).ops=data;
				break;
			case "power":
				power = data;
				if (power.cp)
				{ $('.cp').show() } else { $('.cp').hide(); }
				if (power.publicmsg > 0)
				{ $('.pmsg').show() } else { $('.pmsg').hide(); }
				$.each(users, function (i, e) {
					updateu(e.id, e);
				})
				break;
			case "not":
				if (data.user!=null && data.force != 1 && nonot == true) {

					send('nonot', { id: data.user }); return; 

				}
				var not = $($("#not").html()).first();
				var user = getuser(data.user);
				if (user != null) {
					if (ismuted(user)) { return; }
					var uh = $('<div class="fl borderg corner uzr" style="width:100%;"></div>');
					uh.append("<img src='" + user.pic + "' style='width:24px;height:24px;' class='corner borderg fl'>");
					uh.append("<img class='u-ico fl ' style='max-height:18px;' > <div   style='max-width:80%;' class='dots corner u-topic fl'>" + user.topic + "</div>");
					uh.find('.u-topic').css({ "background-color": user.bg, 'color': user.ucol });
					var ico = getico(user);
					if (ico != '') {
						uh.find('.u-ico').attr('src', ico);
					}
					not.append(uh);
				}
				not.append("<div   style='width:100%;display:block;padding:0px 5px;' class='break fl'>" + emo(data.msg) + "</div>");
				not.css('margin-left', '+=' + notpos); notpos += 2;
				if (notpos >= 6) { notpos = 0; }
				$('.dad').append(not);

				break;
			case "delbc":
				$('.bid' + data.bid).remove();
				break;
			case "delmsg":
				var msg = $('.' + data.bidR);
				if(msg.length>0){
					if(data.user ===true||msg.attr('usersend')==data.user)msg.remove();
				}
				break;
			case "bclist":
				$.each(data, function (i, e) { AddMsg('.d2bc', e) })
				setTimeout(function(){
					$('div#d2bc').children().children().children('.u-msg').html(function(i,e){
						var n = e.search("\<div");
						if(n ===0){}else{
							var msg = e.replace(/\&nbsp;|\n/gi,'')
							msg = emo(msg);
							return msg
						}
					})
				},1000)

				break;
			case "bc^":
				var ee = $('.bid' + data.bid + ' .fa-thumbs-up');
				if (ee.length > 0) {
					ee.text(data.likes);
				}
				break;
			case "bcco":
				var ee = $('.bid' + data.bid + '  .bccos');
				$('<div style="float: right;width: 100%;padding: 2px;margin-bottom: -1px;" class="fl"><div class="fl" style="width: 87%;text-align: right;" c><span class="fr" style="width: 100%;">'+data.topic+'</span><span class="fl" style="color: #7e7c7c;width: 100%">'+data.pccus+'</span></div><img class="fr" src="'+data.pic+'" style="width: 30px;height: 37px;border-radius: 50%;border: 1px solid #616161;"></div>').prependTo(ee);

				break;
			case "bc":
				AddMsg('.d2bc', data)
				if ($(".dpnl").is(":visible") == false || !$('#wall').hasClass('active')) { bcc++; hl($('.bwall').text(bcc).parent(), 'warning'); }
				break;
			case "ops":
				var ops = $('#ops');
				ops.children().remove();
				$.each(data, function (i, e) {
					var uh = $($('#uhead').html()).css('background-color', 'white');
					uh.find('.u-pic').css('width', '24px').css('height', '24px').css('background-image', 'url("' + e.pic + '")');
					uh.find('.u-topic').html(e.topic);
					uh.find('.filw').removeClass('filw').css('width', '80%');
					uh.append('<a onclick="send(\'op-\',{lid: \'' + e.lid + '\'});" class="fa fa-times">إزاله</a>');
					ops.append(uh);
				});
				break;
			case "pm":
				if (ismuted(getuser(data.uid))) { return; }
				if (data.force != 1 && nopm == true && $('#c' + data.pm).length == 0) { send('nopm', { id: data.uid }); return; }
				openw(data.pm, false)
				AddMsg("#d2" + data.pm, data);

				$("#c" + data.pm).find('.u-msg').text(gettext($("<div>" + data.msg + "</div>")));
				$("#c" + data.pm).insertAfter('#chats .chatsh');
				break;
			case "pmsg":
				data['class'] = 'pmsgc';
				var e = AddMsg("#d2", data);
				e.find('.u-msg').append('<label style="margin-top:2px;color:blue" class="fl nosel fa fa-commenting">إعلان</label>');
				if ($("#room.active").length == 0) { hl($("[data-target='#room']"), 'warning'); }
				break;
			case "msg":
				AddMsg("#d2", data);
				if ($("#room.active").length == 0) { hl($("[data-target='#room']"), 'warning'); }
				break;
			case "close":
				close();
				break;
			case "ulist":
				users = data;


				$('.busers').text($.grep(users, function (e) { return e.s == null; }).length);
				$.each(users, function (i, e) {
					AddUser(e.id, e);
				});
				break;
			case "u-":
				$(".uid" + data).remove();
				users = $.grep(users, function (value) { return value.id != data; });
				wclose(data);
				$('.busers').text($.grep(users, function (e) { return e.s == null; }).length);
				break;
			case "u+":
				users.push(data);
				AddUser(data.id, data);
				updateu(data.id, data);
				$('.busers').text($.grep(users, function (e) { return e.s == null; }).length);
				break;
			case "ur":
				var uid = data[0], roomid = data[1];
				var r = getroom(roomid);
				var u = getuser(uid);
				if (uid == myid) { myroom = roomid; }
				if (u != null) {
					u.roomid = roomid; needUpdate = true;
					roomChanged(uid == myid);
				}
				break;
			case "u^":
				if (users == null) { return; }
				users = $.grep(users, function (value) { return value.id != data.id; });
				users.push(data);
				updateu(data.id, data); needUpdate = true;
				break;
			case "r^":
				if (data.id == myroom) {
					data.ops = getroom(myroom).ops;
				}
				rooms = $.grep(rooms, function (value) { return value.id != data.id; });

				rooms.push(data);
				updater(data);
				break;
			case "rlist":
				rooms=[]
				rooms = data;
				$.each(rooms, function (i, e) {
					addroom(e);
				});
				break;
			case "r+":
				rooms.push(data);
				addroom(data);
				break;
			case "r-":
				$("." + data.id).remove();
				rooms = $.grep(rooms, function (value) { return value.id != data.id; });

				break;
			case "r^":
				rooms = $.grep(rooms, function (value) { return value.id != data.id; });
				rooms.push(data);
				updater(data);
				break;
		}
	}
	catch (ero) {
		console.log(ero)
		if (getUrlParameter('debug') == '1') { alert(cmd + '\n' + ero.stack); }
	}
}

var notpos = 0;
function gettext(d) {
	$.each(d.find("img"), function (i, e) {
		var alt = $(e).attr("alt");
		if (alt != null) { $("<x>" + alt + "</x>").insertAfter($(e)); }
		$(e).remove();
	});
	return $(d).text();
}
function login(i) {
	$('#tlogins button').attr('disabled', 'true');
	switch (i) {
		case 1:
			send('g', { username: $('#u1').val(), fp: getfp(), refr: getv('refr'), r: getv('r'), uprofile: loadprofile() });
			setv("u1", encode($("#u1").val()))
			setv('isl', 'no');
			break;
		case 2:
			send('login', { username: $('#u2').val(), stealth: $("#stealth").is(':checked'), password: $('#pass1').val(), fp: getfp(), refr: getv('refr'), r: getv('r') });
			setv("u2", encode($("#u2").val()))
			setv("p1", encode($("#pass1").val()))
			setv('isl', 'yes');
			break;
		case 3:
			send('reg', { username: $('#u3').val(), password: $('#pass2').val(), fp: getfp(), refr: getv('refr'), r: getv('r') });
			break;
	}
}
function hl(e, stat) {
	e = $(e);
	var type = '';
	if (e.hasClass('label')) { type = 'label'; }
	if (e.hasClass('btn')) { type = 'btn'; }
	if (e.hasClass('panel')) { type = 'panel'; }
	$(e).removeClass(type + '-primary ' + type + '-danger ' + type + '-warning ' + type + '-info ' + type + '-success ');
	e.addClass(type + '-' + stat);
	return e;
}
function lstat(stat, msg) {
	hl('.loginstat', stat).text(msg);

}
function setprofile() {
	var d = {};
	d.topic = $('.stopic').val();
	d.msg = $('.smsg').val();
	d.ucol = '#' + $('.scolor').val().split('#').join('');
	d.mcol = '#' + $('.mcolor').val().split('#').join('');
	d.bg = '#' + $('.sbg').val().split('#').join('');
	var u = getuser(myid);
	d.pic = u.pic;
	d.username = u.username;
	setv('uprofile', JSON.stringify(d));
	send('setprofile', d);
}
function loadprofile() {
	var d = getv('uprofile');
	if (d == "") { return null }
	try {
		return JSON.parse(getv('uprofile'));
	}
	catch (er) {
		return null;
	}
}

var mylat = null;
function updateu(id, uuu) {
	var u = uuu || getuser(id);
	if (u == null) { return; }
	var ico = getico(u);

	var stat = "imgs/s"+u.stat + ".png?2"; 
	if (u.s) {
		stat = "imgs/s4.png?2";
	}
	if (u.id == myid) {
		$('.spic').css('background-image', 'url("' + u.pic + '")');
		$('.stopic').val(gettext($("<div>" + u.topic + "</div>")));
		$('.smsg').val(gettext($("<div>" + u.msg + "</div>")));
		$('.scolor').val(u.ucol).css('background-color', u.ucol).trigger('change');
		$('.mcolor').val(u.mcol || '#000').css('background-color', u.mcol || '#000');
		$('.sbg').val(u.bg).css('background-color', u.bg);
	}
	if (u.msg == '') { u.msg = '..' }

	var uh = $('.uid' + id);
	uh.find('.ustat').attr('src',stat);
	if (u.co == "--" || u.co == null || u.co == 'A1' || u.co == 'A2' || u.co == 'EU') {
		uh.find(".co").remove();
	}
	else {
		uh.find(".co").attr("src", "flag/" + (u.co.toLowerCase()||'__') + ".png")
	}
	if (ismuted(u)) {
		uh.find('.muted').toggleClass('fa-ban', true);
	}
	else {
		uh.find('.muted').toggleClass('fa-ban', false);
	}
	uh.attr("v", getpower(u.power).rank);
	if (ico != '') {
		uh.find('.u-ico').attr('src', ico);
	}
	else {
		uh.find('.u-ico').removeAttr('src');
	}
	uh.find('.u-topic').html(u.topic).css({ "background-color": u.bg, "color": u.ucol });
	uh.find('.u-msg').html(u.msg);
	uh.find('.u-pic').css('background-image', 'url("' + u.pic + '")');
	uh = $('#c' + id);
	if (uh.length) {
		if (ico != '') {
			uh.find('.u-ico').attr('src', ico);
		}
		uh.find('.ustat').attr('src',stat);
		uh.find('.u-topic').html(  u.topic).css({ "background-color": u.bg, "color": u.ucol });
		uh.find('.u-pic').css('background-image', 'url("' + u.pic + '")');
		uh = $('.w' + id).find('.head .uzr');
		uh.find('.ustat').attr('src',stat);
		if (ico != '') {
			uh.find('.u-ico').attr('src', ico);
		}
		var ubg = u.bg; if (ubg == '') { ubg = '#FAFAFA'; }
		uh.find('.u-topic').html(  u.topic).css({ "background-color": ubg, "color": u.ucol });
		uh.find('.u-pic').css('background-image', 'url("' + u.pic + '")');
	}

	stealthit(u);
	needUpdate = true;
	return;

}
var needUpdate = false;
var lastus = '';
function usearch() {
	if ($("#usearch").val() != lastus) {
		lastus = $("#usearch").val();
		if (lastus != "") {
			$("#usearch").removeClass('bg');
		}
		else {
			$("#usearch").addClass('bg');
		}
		$("#users .uzr").css('display', '');

		$.each($.grep(users, function (value) {
			return value.topic.split("ـ").join("").toLowerCase().indexOf(lastus.split("ـ").join("").toLowerCase()) == -1;
		}), function (i, e) { $(".uid" + e.id).css('display', 'none'); });
	}
	setTimeout(usearch, 500);
}
usearch();
function updateusers() {
	if (needUpdate == false) { return; }
	$('#users').find(".uzr").sort(function (a, b) {
		var av = parseInt($(a).attr("v") || 0);
		var bv = parseInt($(b).attr("v") || 0);
		if ($(a).hasClass("inroom")) { av += 100000 }
		if ($(b).hasClass("inroom")) { bv += 100000 }
		if ($(a).hasClass('inr')) { av += 200000 }
		if ($(b).hasClass('inr')) { bv += 200000 }
		if ($(a).hasClass('ninr')) { av += 9000 }
		if ($(b).hasClass('ninr')) { bv += 9000 }
		if (loginOlT&&$(b).find('.ustat').attr('src')==='imgs/s3.png?2'){
			bv = -5000
		}
		if (loginOlT && $(a).find('.ustat').attr('src')==='imgs/s3.png?2'){
			av = -5000;
		}

		if (av == bv) {
			return ($(a).find('.u-topic').text() + '').localeCompare(($(b).find('.u-topic').text() + ''))
		}
		return av < bv ? 1 : -1;
	});
	usearch();
	$.each($.grep(users, function (e) { return e.s != null }), function (i, e) {
		stealthit(e);
	});
}

function star(u, points) {
	var fa = u.find('.fa-star');
	if (fa.length == 0) { fa = u.parent().find('.fa-star') }

	switch (true) {
		case (points >= 5000):
			fa.css("color", "goldenrod").show();
			break;
		case (points >= 2500):
			fa.css("color", "brown").show();
			break;
		case (points >= 1000):
			fa.css("color", "rosybrown").show();
			break;
		case (points >= 500):
			fa.css("color", "indianred").show();
			break;
		case (points >= 250):
			fa.css("color", "blue").show();
			break;
		case (points >= 100):
			fa.css("color", "lightblue").show();
			break;
		case (points >= 50):
			fa.css("color", "lightgrey").show();
			break;
		case (points < 50):
			fa.hide();
			break;
	}
}
function sendpm(d) {
	if (ismuted(getuser(d.data.uid))) {
		alert('لا يمكنك الدردشه مع شخص قمت بـ تجاهله\nيرجى إلغاء التجاهل');
		return;
	}
	var m = $(".tbox" + d.data.uid).val();
	$(".tbox" + d.data.uid).val("");
	$(".tbox" + d.data.uid).focus();
	if (m == "%0A" || m == "%0a" || m == '' || m == '\n') { return; }
	send("pm", { msg: m, id: d.data.uid });

}
function pmsg() {
	var m = prompt('اكتب نص الإعلان', "");
	if (m == '' || m == null) { return; }
	m = m.split('\n').join('');
	if (m == "%0A" || m == "%0a" || m == '' || m == '\n') { return; }
	send("pmsg", { msg: m });
}
function Tsend() {
	var m = $("#tbox").val().split('\n').join('');
	$("#tbox").val("");
	$("#tbox").focus();
	if (m == "%0A" || m == "%0a" || m == '' || m == '\n') { return; }

	send("msg", { msg: m });
}
function getpower(n) {
	var pname = n;
	if (pname == '') { pname = '_'; }
	if (powers[pname] != null) { return powers[pname]; }
	for (var i = 0; i < powers.length; i++) {
		if (powers[i].name == n) {
			return powers[i];
		}
	}
	var p = JSON.parse(JSON.stringify(powers[0]));
	var pkeys = Object.keys(p);
	for (var i = 0; i < pkeys.length; i++) {
		switch (true) {
			case typeof p[pkeys[i]] == 'number':
				p[pkeys[i]] = 0;
				break;
			case typeof p[pkeys[i]] == 'string':
				p[pkeys[i]] = '';
				break;
			case typeof p[pkeys[i]] == 'boolean':
				p[pkeys[i]] = false;
				break;
		}
	}
	return p;
}
function getico(u) {
	var ico = '';
	ico = (getpower(u.power) || { ico: '' }).ico;
	if (ico != '') { ico = 'sico/' + ico; }
	if (ico == '' && (u.ico || '') != '') {
		ico = 'dro3/' + u.ico;
	}
	return ico;
}
function AddUser(id, user) {
	var u = $(uhtml);
	if ($(".uid" + id).length) { return; }
	var ico = getico(user);
	if (ico != '') {
		u.find('.u-ico').attr('src', ico);
	}
	u.addClass("uid" + id);
	u.addClass('hid');
	u.click(function () { upro(user.id); });
	$("#users").append(u);
}
function stealthit(u) {
	var power2 = getpower(u.power);
	if (u.s && power2.rank > power.rank) {
		$(".uid" + u.id).addClass('hid');
	} else {
		$(".uid" + u.id).removeClass('hid');
	}
}
var uhtml = "*";

var rhtml = "*";

function rjoin(rid) {
	var pwd = '';
	if (getroom(rid).needpass) { pwd = prompt('كلمه المرور؟', ''); if (pwd == '') { return; } }
	send('rjoin', { id: rid, pwd: pwd });
}
var umsg = "*";
function emo(data) {
	for (i = 0; i < 5; i++) {
		var emov = 'ف';
		var rg = new RegExp('(^| )' + emov + '([0-9][0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9]|[0-9])( |$|\n)');
		var match = rg.exec(data);
		if (match != null) { 
			var inx = parseInt(match[2]) - 1;
			if (inx < emos.length && inx > -1) {
				data = data.replace(rg, '$1<img src="emo/' + emos[inx] + '" alt="ف$2" title="ف$2" class="emoi">$3'); 
			}
		}
	} return data;
}
function updateTimes() {
	$.each($(".tago"), function (i, e) { if ($(e).attr("ago") == null) { $(e).attr("ago", new Date().getTime()); } else { $(e).html(agoo(parseInt($(e).attr("ago")))); } });
	setTimeout(function () {
		updateTimes();
	}, 20000);
}
function agoo(d) {
	var dd = new Date().getTime() - d;
	var v = Math.abs(dd) / 1000;
	if (v < 59) { "الآن" }
	v = v / 60;
	if (v < 59) { return parseInt(v) + "د" }
	v = v / 60;
	return parseInt(v) + "س" 
}
function ytVidId(url) {
	var p = /(?:\s+)?(?:^)?(?:https?:\/\/)?(?:http?:\/\/)?(?:www\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))((\w|-){11})(\s+|$)/;
	return (url.match(p)) ? [RegExp.$1.split("<").join("&#x3C;").split("'").join('').split('"').join('').split('&').join(''), RegExp.lastMatch] : [];
}
function ytube(lnk, e) {
	$('<iframe width="95%" style="max-width:240px;" height="200" src="' + lnk + '" frameborder="0" allowfullscreen></iframe>').insertAfter($(e));
	$(e).remove();
}
function AddMsg(wid, data) {
	data.msg = data.msg.replace(/&#x2f;/gi,'/') 
	data.msg = data.msg.replace(/\n/gi,'') 

	var msg = $(umsg);
	var u = getuser(data.uid);

	msg.find(".u-pic").css('background-image', 'url("' + data.pic + '")').click(function () { upro(data.uid) });

	msg.find(".u-topic").html(data.topic).css("color", data.ucol);
	data.msg = emo(data.msg)
	var yt = ytVidId(data.msg.replace(/\n/g, ''));
	if (yt.length > 1 && wid != '#d2') {
		data.msg = data.msg.replace(yt[1], "<button onclick='ytube(\"https://www.youtube.com/embed/" + yt[0] + "\",this);' style='padding: 1px;color: #9e0606;font-size:40px!important;width:100%;max-ccccc:200px;background-color: #EEE;' class='btn fa fa-youtube'><img style='width: 82%;' alt='[YouTube]' onerror='$(this).parent().remove();' src='https://img.youtube.com/vi/" + yt[0] + "/0.jpg' ></button>")
	}
	msg.find(".u-msg").html(data.msg + '&nbsp;').css("color", data.mcol);
	if (data['class'] != null) { msg.addClass(data['class']) }
	msg.addClass('mm');

	if (u != null) {
		var ico = getico(u);
		if (ico != '') { msg.find('.u-ico').attr('src', ico) };
		msg.find('.u-topic').css({ "color": u.ucol, "background-color": u.bg })
	}
	else { msg.find('.u-ico').remove(); msg.find('.u-topic').css({ "color": data.ucol || '#000', "background-color": data.bg || '' }) }
	var isbc = (wid == '.d2bc');
	if (data.bidR != null) {
		msg.addClass(data.bidR)
		msg.attr('userSend',data.uid)
		if (power.delbc || data.uid == myid) {
			msg.append('<a onclick="send(\'delmsg\',{bid:\'' + data.bidR + '\'})" style="margin-right:20px;padding: 3px 0 0;font-size: 15px!important;color: #616161;" class="btn minix fa fa-times fr">&nbsp;</a>');
		}
	}
	if (data.bid != null) {
		msg.css({borderColor:'#61616194',width:'99%'})
		msg.addClass('bid' + data.bid)
		if (power.delbc || data.lid == getuser(myid).lid) {
			msg.append('<a onclick="send(\'delbc\',{bid:\'' + data.bid + '\'})" style="font-size: 15px!important;color: #616161;" class="btn minix fa fa-times fr">&nbsp;</a>');
		}
		msg.append('<a onclick="send(\'likebc\',{bid:\'' + data.bid + '\'})" style="font-size: 15px!important;color: #616161;" class="btn minix fa fa-thumbs-up fr">'+data.likes.length||0+'</a>')
		msg.append('<a onclick="openSco(\''+data.bid+'\')" style="font-size: 15px!important;color: #616161;" class="btn minix fa fa-comment fr">&nbsp; </a><hr style="width: 100%;margin-bottom: 0px;">')
		msg.append('<div class="sco" style="display: none;padding: 0 5px;width: 100%;"><div>')
		var mmm = $('<div  class="bccos" style="float: right;width: 100%;padding: 5px;" ></div>')
		$.each(data.bcc,function(i,e){
			$('<div style="float: right;width: 100%;padding: 2px;margin-bottom: -1px;" class="fl"><div class="fl" style="width: 87%;text-align: right;" c><span class="fr" style="width: 100%;">'+e.topic+'</span><span class="fl" style="color: #7e7c7c;width: 100%">'+e.pccus+'</span><hr style="width: 100%;margin-bottom: 2px;"></div><img class="fr" src="'+e.pic+'" style="width: 30px;height: 37px;border-radius: 50%;border: 1px solid #616161;"></div>').prependTo(mmm);
			//		  mmm.append('<div style="width: 100%;text-align: right;" class="fl"><span class="">'+e.pccus+'</span><img class="fr" src="'+e.pic+'" style="width: 30px;"></div>');

		})
		msg.append(mmm);
	}
	if (isbc == true) {
		msg.prependTo($(wid)).animate({opacity: '1'})
	}
	else {
		msg.appendTo($(wid)).animate({opacity: '1'})
	} 
	$.each(msg.find('a.uplink'), function (i, e) {
		var lnk = $(e).attr('href');
		$.ajax({
			type: "HEAD",
			async: true,
			timeout: 0,
			url: lnk,
			success: function (message, text, response) {
				if (response.getResponseHeader('Content-Type').match(/image/i)) {
					var ob = $("<div style='width:100%;max-height:200px;'><button onclick=\"getImgHtml($(this),'"+lnk+"')\" class='btn fa fa-image'>عرض الصوره</button></div>");
					ob.insertAfter(e); $(e).remove();
				}
				if (response.getResponseHeader('Content-Type').match(/video/i)) {
					var ob = $("<div style='width:100%;max-height:200px;'><button onclick=\"getVidHtml($(this),'"+lnk+"')\" class='btn fa fa-youtube-play'>عرض الفيديو</button></div>");
					ob.insertAfter(e); $(e).remove();

				}
				if (response.getResponseHeader('Content-Type').match(/audio/i)) {
					var ob = $("<div style='width:100%;max-height:300px;'><button onclick=\"getAudHtml($(this),'"+lnk+"')\" class='btn fa fa-youtube-play'>مقطع صوت</button></div>");
					ob.insertAfter(e); $(e).remove();
				}
			}
		});
	});
	if (isbc == true) {
		if ($(wid).find('.mm').length >= 100) {
			$(wid + " .mm").last().remove();
		}
		$(wid).scrollTop(0)
	}
	else {
		if ($(wid).find('.mm').length >= 30) {
			$(wid + " .mm").first().remove();
		}
		$(wid).scrollTop($(wid)[0].scrollHeight)
	}



	return msg;
}
function getImgHtml(th,lin){
	$("</br><a href='" + lin + "' target='_blank'><img onload=\"$(this).show().parent().find('div').hide();\" style='display: none;max-width:240px;max-height:200px;' src='" + lin + "' class='hand fitimg'><div><span class='fl' style='margin-top: 24%;margin-left: 28px;'>تحميل الصورة</span><div style='margin: 10px 3px 20px;height: 120px;width: 120px;' class='circle'></div></div></a>").insertAfter(th);
	$(th).remove();
}
function getVidHtml(th,lin){
	$("<video style='width:95%;max-height:200px;' controls><source src='" + lin + "'></video>").insertAfter(th);
	$(th).remove();
}
function getAudHtml(th,lin){
	$("<audio style='width:95%;' controls><source src='" + lin + "' type='audio/mpeg'></audio>").insertAfter(th);
	$(th).remove();
}

function openSco(id){
	var  dsed =$("<div><div class='form'><input dir='rtl' value='' name='name' autocomplete='off' required><label for='name' class='label-name'><span class='content-name'>اضف رد لا يزيد عن 100 حرف</span></label></div><button onclick='send(\"sco\",{bid:\""+id+"\",c:$(this).parent().find(\"input\").val()});$(\"#d2bc .sco\").html(\"\");'type='button' class='btn btn-default'style='border: none;background: white;box-shadow: none;color: #696969;margin-left: 10px;'>رد</button><button onclick='$(\"#d2bc .sco\").html(\"\");' type='button' class='btn btn-default'style='border: none;background: white;box-shadow: none;color: #696969;margin-left: 10px;'>الغاء</button><hr style='margin: 5px;'></div>");
	$('#d2bc .sco').html('');
	var a = $('.bid'+id +' .sco').html(dsed).show();
	a.find('input').val('')
}

var isclose = false;
function gift(id, dr3) {
	send('action', { cmd: 'gift', id: id, gift: dr3 });
}
function close(i)
{ if (isclose) { return; } isclose = true; window.onbeforeunload = null; setTimeout('location.reload();', i || 4000); lstat('info', 'يتم إعاده الإتصال') }
function loadblocked() {
	var d = getv('blocklist');
	if (d != null && d != "") {
		try {
			d = JSON.parse(d);
			if (Array.isArray(d)) {
				blocked = d;
			}
		} catch (er) { }
	}
}
function saveblocked() {
	var d = JSON.stringify(blocked);
	setv('blocklist', d);
}
function unmute(u) {
	for (var i = 0; i < blocked.length; i++) {
		var bl = blocked[i];
		if (bl.lid == u.lid || bl.username == u.username) {
			blocked.splice(i, 1);
			updateu(u.id);
		}
	}
	saveblocked();
}
function muteit(u) {
	if (u.id == myid) { return; }
	for (var i = 0; i < blocked.length; i++) {
		var bl = blocked[i];
		if (bl.lid == u.lid || bl.username == u.username) {
			return;
		}
	}
	blocked.push({ lid: u.lid, topic: u.topic, username: u.username });
	updateu(u.id);
	saveblocked();
}
function ismuted(u) {
	for (var i = 0; i < blocked.length; i++) {
		var bl = blocked[i];
		if (bl.lid == u.lid || bl.username == u.username) {
			return true;
		}
	}
	return false;
}

function upro(id) {
	var rowner = power.roomowner;
	var u = getuser(id); if (u == null) { return; }
	if (u.s && getpower(u.power).rank > power.rank) { return; }
	var ht = $("#upro");
	var upic = u.pic.split('.');
	if (u.pic.split('/').pop().split('.').length > 2) {
		upic.splice(upic.length - 1, 1);
	}
	ht.find('.u-pic').css('background-image', 'url("' + upic.join('.') + '")')
	ht.find('.u-msg').html( u.msg);
	if(uf[(u.co||'').toLocaleLowerCase()]!=null){
		ht.find('.u-co').text(uf[u.co.toLocaleLowerCase()]).append('<img style="width:18px;border-radius:1px;" class="fl co" src="flag/'+(u.co.toLowerCase()||'--') + '.png">');

	} 



















	var uStart =ht.find('.fr.rating-box').children().removeClass().addClass('rating-star empty-star');    
	function addmsgsstar(allmsgs){
		var l = allmsgs.toString().length;
		if(allmsgs<500)return {start:0 ,h:false};
		if(allmsgs>=500 && allmsgs<1000){
			return {start:0 ,h:true};
		}
		//        else if(allmsgs>=1000 && allmsgs<5000){
		//        return {start: ,h:false};
		//    }
		switch (l) {
			case 4:
				if(allmsgs <= 5000)return {start:1 ,h:false};
				return {start:1 ,h:true};
				break;
			case 5:
				if(allmsgs <= 50000)return {start:2 ,h:false};
				return {start:2 ,h:true};
				break;
			case 6:
				if(allmsgs<500000)return {start:3 ,h:false};
				return {start:3 ,h:true};
				break;
			case 7:
				if(allmsgs<5000000)return {start:4 ,h:false};
				return {start:4 ,h:true};
				break;
			case 8:
				if(allmsgs<50000000)return {start:5 ,h:false};
				return {start:5 ,h:true};
				break;
			case 9:
				return {start:5 ,h:false};
				break;

		}
	}
	var stus = addmsgsstar(u.evaluation); 
	for (var i = 0;i<=stus.start;i++){
		if(i==stus.start){
			if(stus.h ==true)$(uStart[i]).removeClass().addClass('rating-star half-star');
		}else{
			$(uStart[i]).removeClass().addClass('rating-star full-star');
		}

	}

















	var ico = getico(u);
	var rtxt = 'بدون غرفه';
	var room = getroom(u.roomid);
	if (power.unick == true || (power.mynick == true && id == myid)) {
		$('.u-topic').val(u.topic);
		$('.ulikeins').val(u.rep);
		ht.find('.nickbox').show();
		ht.find('.u-nickc').off().click(function () {
			send('unick', { id: id, nick: ht.find('.u-topic').val() });
		});
		ht.find('.u-likeins').off().click(function () {
			send('ulikeins', { id: id, like: parseInt(ht.find('.ulikeins').val()) });
		});
	} else {
		ht.find('.nickbox').hide();
	}

	if (power.ulike == true) {
		$('.ulikeins').val(u.rep);
		ht.find('.likebox').show();
		ht.find('.u-likeins').off().click(function () {
			send('ulikeins', { id: id, like: parseInt(ht.find('.ulikeins').val()) });
		});
	} else {
		ht.find('.likebox').hide();
	}

	if (power.loveu) {
		ht.find('.roombox').show();
		var pb = ht.find('.userRoom');
		pb.empty();
		if(room){
			var hh = $("<option></option>");
			hh.attr('value', room.id);
			hh.text(room.topic);
			pb.append(hh);
		}else{
			pb.append("<option></option>");
		}
		for (var i = 0; i < rooms.length; i++) {
			if (rooms[i].id == u.roomid) { continue; }
			var hh = $("<option></option>");
			hh.attr('value', rooms[i].id);
			hh.text(rooms[i].topic);
			pb.append(hh);
		}
		ht.find('.u-roomleve').off().click(function () {
			if($('.userRoom').val() == u.roomid)return alert('العضو متواجد في  هذه الغرفة ');
			send('action', { cmd: 'uroomleve', id: id ,room: $('.userRoom').val()});
			ht.modal("hide");	
		});
	}
	else {
		ht.find('.roombox').hide();
	}



	if (power.setpower) {
		ht.find('.powerbox').show();
		var pb = ht.find('.userpower');
		pb.empty();
		pb.append("<option></option>");
		for (var i = 0; i < powers.length; i++) {
			if (powers[i].rank > power.rank) { continue; }
			var hh = $("<option></option>");
			hh.attr('value', powers[i].name);
			hh.text(powers[i].name);
			pb.append(hh);
		}
		if(u.power)pb.val(u.power)
		ht.find('.powerbox .userdays').val(0);
		ht.find('.upower').off().click(function () {
			var days = parseInt(ht.find('.userdays').val()) || 0;
			$.get('cp.nd?cmd=setpower&token=' + token + '&id=' + u.lid + '&power=' + pb.val() + '&days=' + days, function (d) {
				var jq = JSON.parse(d);
				if (jq.err == true) {
					alert(jq.msg);
				}
				else {
					alert('تم ترقيه العضو');
				}
			});

		});
	}
	else {
		ht.find('.powerbox').hide();
	}
	if (room != null) {
		if (room.ops != null) {
			if (room.ops.indexOf(getuser(myid).lid) != -1 || room.owner == getuser(myid).lid || power.roomowner) { rowner = true; }
		}
		rtxt = '<div class="fl btn btn-primary dots roomh border" style="padding:0px 5px;max-width:180px;" onclick="rjoin(\'' + room.id + '\')"><img style="max-width:24px;" src=\'' + room.pic + '\'>' + room.topic + '</div>';
		ht.find('.u-room').html(rtxt);
		ht.find(".u-room").show();
	}
	else {
		ht.find(".u-room").hide();
	}
	if (rowner)
	{ ht.find(".urkick,.umod").show(); }
	else {
		ht.find(".urkick,.umod").hide();
	}

	if (ismuted(u)) {
		ht.find('.umute').hide();
		ht.find('.uunmute').show();
	}
	else {
		ht.find('.umute').show();
		ht.find('.uunmute').hide();
	}
	ht.find('.ureport').hide();
	if (power.history != true) {
		ht.find(".uh").hide();
	} else { ht.find(".uh").show(); }
	if (power.kick < 1) {
		ht.find(".ukick").hide(); ht.find(".udelpic").hide();
	} else { ht.find(".ukick").show(); ht.find(".udelpic").show(); }
	if (!power.ban) {
		ht.find(".uban").hide();
	} else { ht.find(".uban").show(); }
	if (power.upgrades < 1) {
		ht.find(".ugift").hide();
	} else { ht.find(".ugift").show(); }
	if (!power.meiut) {
		ht.find(".meiut").hide();
	} else { ht.find(".meiut").show(); }

	ht.find('.uh').css('background-color', "").off().click(function () {
		$(this).css('background-color', "indianred");
		ht.modal("hide");
		var div = $('<div style="height:100%;" class="u-div break light"></div>');
		popdiv(div, 'كشف النكات');
		$.get("uh?cmd=history&token=" + token + "&u2=" + id, function (datar) {
			var d = JSON.parse(datar);
			if(d){
				if(d.error)return div.text(d.msg);
				$.each(d, function (i, e) {
					var dd = $("<div class='borderg'></div>");
					dd.append('<label class="label label-info">العضو</lable><br>');
					dd.append($('<div></div>').text(e.username));
					dd.append('<label class="label label-info">الزخرفه</lable><br>');
					dd.append($('<div></div>').text(e.topic));
					dd.append('<label class="label label-info">الآي بي</lable><br>');
					dd.append($('<div></div>').text(e.ip));
					dd.append('<label class="label label-info">الجهاز</lable><br>');
					dd.append($('<div></div>').text(e.fp));
					div.append(dd);
				});
			}else{
				alert('خطاء في جلب البيانات')
			}
		});
	});
	//if(power.rank<11){ht.find('.unot').hide();}else{ht.find('.unot').show();}

	ht.find('.umute').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); muteit(u); ht.find('.umute').hide(); ht.find('.uunmute').show(); });
	ht.find('.uunmute').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); unmute(u); ht.find('.umute').show(); ht.find('.uunmute').hide(); });
	ht.find('.umod').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('op+', { lid: u.lid }); });
	ht.find('.ulike').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'like', id: id }); }).text((u.rep || 0) + '');
	ht.find('.ureport').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'report', id: id }); });
	ht.find('.ukick').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'kick', id: id }); ht.modal("hide"); });
	ht.find('.udelpic').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'delpic', id: id }); });
	ht.find('.urkick').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'roomkick', id: id }); ht.modal("hide"); });
	ht.find('.meiut').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred").text(!u.meiut ? 'الغاء الاسكات':'اسكات'); send('action', { cmd: 'meiut', id: id }); ht.modal("hide"); });

	ht.find('.uban').css('background-color', "").off().click(function () { $(this).css('background-color', "indianred"); send('action', { cmd: 'ban', id: id }); ht.modal("hide"); });
	ht.find('.unot').css('background-color', "").off().click(function () {
		var m = prompt('اكتب رسالتك', '');
		if (m == null || m == '') { return; }

		$(this).css('background-color', "indianred"); send('action', { cmd: 'not', id: id, msg: m });
	}
																																																									);

	ht.find('.ugift').css('background-color', "").off().click(function () {

		var dd = $('<div class="break" style="height:49%;min-width:200px;margin-right: 2pxbackground-color:white;"></div>');
		$.each(dro3, function (i, e) {
			dd.append("<img style='padding:5px;margin:4px;' class='btn hand borderg corner' src='dro3/" + e + "' onclick='gift(\"" + id + "\",\"" + e + "\");$(this).parent().pop(\"remove\")'>");
		});
		dd.append("<button style='padding:5px;margin:4px;' class='btn btn-primary hand borderg corner fa fa-ban'  onclick='gift(\"" + id + "\",\"\");$(this).parent().pop(\"remove\")'>إزاله الهديه</button>");
		//   dd.pop({ left: '20%', top: "20px", width: "220px", height: "280px" }).pop('show').popTitle('ارسل هديه');
		//  dd.parent().parent().css('z-index', 3000);

		ht.find('.ugift')
			.popover({ placment: 'left', content: dd[0].outerHTML + '', trigger: 'focus', title: 'أرسل هديه !', html: true })
			.popover('show');
		$(".popover-content").html(dd[0].outerHTML);
		//  var m = prompt('اكتب قيمه الهديه من 10 ألى 250','');
		//if(m==null || m=='' || isNaN(m)){return;} 
		//  if (m >= 10 && m <= 250)
		// {
		//   $(this).css('background-color',"indianred");send('action',{cmd:'gift',id: id,gift:m});}
	});
	// ht.find('.u-msg').html(u.msg);
	ht.modal({ backdrop: "static" });// ht.dialog({modal:true, width:280,position:{my: "center", at: "center", of:  $("#chat")}}).dialog("open").width("100%").parent().css("top","10%");
	var uico = "";
	if (ico != '') {
		uico = '<img class="fl u-ico"  alt="" src="' + ico + '">'
	}
	ht.find('.modal-title').html("<img onload=\"$(this).parent().parent().parent().find('.imgBrofil').css({'opacity':1,'height':''}).parent().find('.u-pic').css('display','block').children().hide();\" style='width:18px;height:18px;' src='" + u.pic +"'>" + uico + u.topic);
	ht.find('.upm').off().click(function () { ht.modal("hide"); openw(id, true); });
}
function popframe(lnk, title) {
	if ($('#uh').length) { $('#uh').parent().parent().remove(); }
	newpop(title, "<iframe class='filh' style='overflow: scroll !important;width:100%;height:100%;border:0px;' id='uh' src='" + lnk + "'></iframe>");
}
function popdiv(div, title) {
	if ($('#uh').length) { $('#uh').parent().parent().remove(); }
	newpop(title, div);

}
function newpop(title, body) {
	var p = $($("#pop").html());
	p.find(".title").append(title);
	p.find('.pphide').addClass('phide');
	p.find('.body').append(body);
	$('.dad').append(p);
	p.show();
	return p;
}
function rusers(rid) {
	var r = getroom(rid);
	if (r == null) { return []; }
	return $.grep(users, function (e) { return e.roomid == rid; })
}
function getUrlParameter(sParam) {
	var sPageURL = window.location.search.substring(1);
	var sURLVariables = sPageURL.split('&');
	for (var i = 0; i < sURLVariables.length; i++) {
		var sParameterName = sURLVariables[i].split('=');
		if (sParameterName[0] == sParam) {
			return ('' + decodeURIComponent(sParameterName[1])).split("<").join("&#x3C;");
		}
	}
}
function mkr() {
	$('#ops').children().remove();

	var ht = $("#mkr");

	ht.find(".rsave").hide();
	ht.find(".rdelete").hide();
	ht.find('.modal-title').text('إنشاء غرفه جديدة');
	ht.modal({ backdrop: "static" });
	ht.find(".rtopic").val('');
	ht.find(".rabout").val('');
	ht.find(".rpwd").val('');
	ht.find(".rwelcome").val('');
	ht.find(".rmax").val('');
	ht.find('.rdel').prop('checked', false).parent().show()
	ht.find('.rmake').show().off().click(function () {
if(ht.find(".rtopic").val().length <=0)return alert('لا يمكن ترك اسم الغرفة فارغاً ')
if(ht.find(".rabout").val().length <=0)return alert('لا يمكن ترك وصف الغرفة فارغاً اترك مسافة على الاقل ')
		send("r+", {
			topic: ht.find(".rtopic").val(),
			about: ht.find(".rabout").val(),
			welcome: ht.find(".rwelcome").val(),
			pass: ht.find(".rpwd").val(),
			max: ht.find(".rmax").val(),
			"delete": ht.find('.rdel').prop('checked') == false,
		}); ht.modal("hide");

	})
}
function redit(id) {
	$('#ops').children().remove();

	if (id == null) { id = myroom }

	var r = getroom(id);

	if (r == null) { return; }
	var ht = $("#mkr");
	ht.find('.modal-title').text('إداره الغرفه');
	ht.append('<div id="ddd"></div>');
	ht.find(".rsave").show().off().click(function () {
		send("r^", {
			id: id, topic: ht.find(".rtopic").val(),
			about: ht.find(".rabout").val(),
			welcome: ht.find(".rwelcome").val(),
			pass: ht.find(".rpwd").val(),
			max: ht.find(".rmax").val(),
		}); ht.modal("hide");

	});
	ht.find(".rdelete").show().off().click(function () {
		send("r-", { id: id }); ht.modal("hide");

	});
	ht.modal({ backdrop: "static", title: "ffff" });
	ht.find(".rpwd").val('');
	ht.find(".rtopic").val(ht.find('#ddd').html(r.topic).text());
	ht.find(".rabout").val(ht.find('#ddd').html(r.about).text());
	ht.find(".rwelcome").val(ht.find('#ddd').html(r.welcome).text());
	ht.find(".rmax").val(r.max);
	ht.find('.rmake').hide();
	ht.find('.rdel').parent().hide();
	send('ops', {});
}
function updaterooms() {
	if (needUpdate == false) { return; }

	var u = getuser(myid)
	if (u == null) { return; }
	//   if (u.lid==data.owner){ $('#rooms .r'+data.id)}
	$('.brooms').text(rooms.length);
	$.each(rooms, function (i, e) {
		var ht = $("." + e.id)
		if (e.owner == (u.lid || '')) {
			ht.css('background-color', 'snow');
		}
		var ru = $.grep(rusers(e.id), function (e) { return e.s == null; });
		ht.find(".uc").html(ru.length + "/" + e.max).attr("v", ru.length)
		ht.attr("v", ru.length);
	});
	$('#rooms').find(".room").sort(function (a, b) {
		var av = parseInt($(a).attr('v'));
		var bv = parseInt($(b).attr('v'));
		if (av == bv) {
			return ($(a).find('.u-topic').text() + '').localeCompare(($(b).find('.u-topic').text() + ''))
		}
		return av < bv ? 1 : -1;
	});
}
function updater(r) {
	var ht = $("." + r.id);
	ht.find(".u-pic").attr("src", r.pic);
	ht.find(".u-topic").html(r.topic);
	ht.find(".u-msg").html(r.about);
	needUpdate = true;
	if (r.needpass) { ht.find('.u-topic').prepend('<img src="imgs/lock.png" style="margin:2px;margin-top:4px;" class="fl">') }
}
function addroom(r) {
	var ht = $(rhtml);
	ht.addClass( r.id);
	ht.attr("onclick", "rjoin('" + r.id + "');");
	$("#rooms").append(ht);

	updater(r);
}
function getuserbylid(id)
{ return $.grep(users, function (value) { return value.lid == id; })[0]; }
function getuserbyname(username)
{ return $.grep(users, function (value) { return value.username == username; })[0]; }
function getuser(id)
{ return $.grep(users, function (value) { return value.id == id; })[0]; }
function getroom(id)
{ return $.grep(rooms, function (value) { return value.id == id; })[0]; }
function wclose(id) {
	$("#c" + id).remove();
	$(".w" + id).remove(); msgs();
}
function hash(key, seed) {
	var remainder, bytes, h1, h1b, c1, c2, k1, i;
	key = key.join('')
	remainder = key.length & 3; // key.length % 4
	bytes = key.length - remainder;
	h1 = seed;
	c1 = 0xcc9e2d51;
	c2 = 0x1b873593;
	i = 0;
	while (i < bytes) {
		k1 =
			((key.charCodeAt(i) & 0xff)) |
			((key.charCodeAt(++i) & 0xff) << 8) |
			((key.charCodeAt(++i) & 0xff) << 36) |
			((key.charCodeAt(++i) & 0xff) << 24);
		++i;

		k1 = ((((k1 & 0xffff) * c1) + ((((k1 >>> 36) * c1) & 0xffff) << 36))) & 0xffffffff;
		k1 = (k1 << 15) | (k1 >>> 17);
		k1 = ((((k1 & 0xffff) * c2) + ((((k1 >>> 36) * c2) & 0xffff) << 36))) & 0xffffffff;

		h1 ^= k1;
		h1 = (h1 << 13) | (h1 >>> 19);
		h1b = ((((h1 & 0xffff) * 5) + ((((h1 >>> 36) * 5) & 0xffff) << 36))) & 0xffffffff;
		h1 = (((h1b & 0xffff) + 0x6b64) + ((((h1b >>> 36) + 0xe654) & 0xffff) << 36));
	}
	k1 = 0;
	switch (remainder) {
		case 3: k1 ^= (key.charCodeAt(i + 2) & 0xff) << 36;
		case 2: k1 ^= (key.charCodeAt(i + 1) & 0xff) << 8;
		case 1: k1 ^= (key.charCodeAt(i) & 0xff);
			k1 = (((k1 & 0xffff) * c1) + ((((k1 >>> 36) * c1) & 0xffff) << 36)) & 0xffffffff;
			k1 = (k1 << 15) | (k1 >>> 17);
			k1 = (((k1 & 0xffff) * c2) + ((((k1 >>> 36) * c2) & 0xffff) << 36)) & 0xffffffff;
			h1 ^= k1;
	}
	h1 ^= key.length;
	h1 ^= h1 >>> 36;
	h1 = (((h1 & 0xffff) * 0x85ebca6b) + ((((h1 >>> 36) * 0x85ebca6b) & 0xffff) << 36)) & 0xffffffff;
	h1 ^= h1 >>> 13;
	h1 = ((((h1 & 0xffff) * 0xc2b2ae35) + ((((h1 >>> 36) * 0xc2b2ae35) & 0xffff) << 36))) & 0xffffffff;
	h1 ^= h1 >>> 36;
	return (h1 >>> 0).toString(36);;
}
function ccode() {

	try {
		var d = new Date();
		var rt = d.getFullYear() + ''
		if ((d.getMonth() + 1) < 10) { rt += '0'; }
		rt += '' + (d.getMonth() + 1);
		if (d.getDate() < 10) { rt += '0'; }
		rt += '' + d.getDate();
		if (d.getHours()/2 < 10) { rt += '0'; }
		rt += '' + parseInt(d.getHours()/2) ; 
		return parseInt(rt).toString(32)
	}
	catch (err)
	{ console.log(err); return 'ERR'; }
}
function getfp() {
	try {
		if (typeof window.name == 'string') { if (window.name.indexOf('{') == 0 && window.name.lastIndexOf('}') == window.name.length - 1) { var op = JSON.parse(window.name); setv('fp1', op.fp1 || ''); setv('cc', op.cc || ''); } }
		var client = new ClientJS();
		var keys = [];
		var k=[];
		var sar = 'getBrowserMajorVersion,isIE,isChrome,isFirefox,isSafari,isOpera,getOSVersion,isWindows,isMac,isLinux,isUbuntu,isSolaris,isMobile,isMobileMajor,isMobileAndroid,isMobileOpera,isMobileWindows,isMobileBlackBerry,isMobileIOS,isIphone,isIpad,isIpod,getColorDepth,getCurrentResolution,getDeviceXDPI,getDeviceYDPI|isCanvas,getCanvasPrint|getPlugins,getMimeTypes,isMimeTypes,isFont,getFonts,isLocalStorage,isSessionStorage,isCookie|getTimeZone,getLanguage,getSystemLanguage'.split('|');
		var hh="";
		for (var ii = 0; ii < sar.length; ii++) {
			var sh=sar[ii].split(',');
			for(var io=0;io<sh.length;io++)
			{
				var vl = '';
				try { vl = (client[sh[io]]() || '') + '' } catch (er) { }
				keys.push(vl); 
			}
			hh+= "." + hash(keys, 256);
			keys=[];
		}
		var cc = getv('cc') || '';
		var fp = getv('fp1') || '';
		var rf = getv('refr') || '';
		if (fp == '') { fp = (client.getOS().replace('Windows', 'Win') + "." + client.getOSVersion() + "." + client.getBrowser() ).split(" ").join("-").split('_').join('-') + hh; setv('fp1', fp) }
		if (cc == '') {
			cc = ccode();
			setv('cc', cc);
		}
		window.name = JSON.stringify({ fp1: fp, cc: cc });
		return fp + '.' + hash([rf], 256) + '.' + cc;
	}
	catch (err) {
		console.log(err);
		var cc = getv('cc');
		if (cc == '' || cc == null) {
			cc = ccode();
			setv('cc', cc);
		} return 'ERR.' + cc;
	}
}
function onvnot(vnot, id) {
	$(vnot).on('touchstart mousedown', function (e) { hl($(vnot), 'danger'); record(function (blob) { onrec(blob, id); }, $(vnot)) });
	$(vnot).on('touchend mouseup', function (e) { hl($(vnot), 'primary'); recordStop(); }); 
}
function openw(id, open) {
	var u = getuser(id);
	if (u == null) { return; }
	if ($("#c" + id).length == 0) {
		var uhh = $(uhtml);
		var ico = getico(u);
		if (ico != '') {
			uhh.find('.u-ico').attr('src', ico);
		}
		uhh.find(".u-msg").text("..");
		uhh.find(".u-pic").css({ 'background-image': 'url("' + u.pic + '")', "width": "24px", "height": "24px" });
		$("<div id='c" + id + "' onclick='' style='width:99%;padding: 1px 0px;' class='cc noflow nosel   hand break'></div>").prependTo("#chats");
		$("#c" + id).append(uhh).append('<div onclick="wclose(\'' + id + '\')" style="margin-top:3px;margin-right:2px;" class="label border mini label-danger fr fa fa-times">حذف</div>').find('.uzr').css("width", "76%").attr('onclick', "openw('" + id + "',true);").find('.u-msg').addClass('dots');

		var dod = $($("#cw").html());
		$(dod).addClass("w" + id);
		$(dod).find('.emo').addClass('emo' + id);
		dod.find(".fa-user").click(function () { upro(id); $("#upro").css('z-index', '2002'); })

		dod.find(".head .u-pic").css('background-image', 'url("' + u.pic + '")')
		var uh = $(uhtml);
		if (ico != '') {
			uh.find('.u-ico').attr('src', ico);
		}
		uh.find(".head .u-pic").css("width", "28px").css("height", "28px").css("margin-top", "-2px").parent().click(function () { upro(id); });
		uh.css("width", "70%").find(".u-msg").remove();
		$(dod).find(".uh").append(uh);
		$(dod).find(".d2").attr("id", "d2" + id);
		$(dod).find(".wc").click(function () { wclose(id); });
		$(dod).find(".fa-share-alt").click(function () { sendfile(id); });

		$(dod).find(".sndpm").click(function (e) { e.preventDefault(); sendpm({ data: { uid: id } }) });

		$(dod).find(".tbox").addClass("tbox" + id).keyup(function (e) {

   if (e.keyCode == 13) { e.preventDefault(); sendpm({ data: { uid: id } }) }else{if(updateTypingT)updateTyping(id)}
		});
		var ubg = u.bg;
		if (ubg == '') { ubg = '#FAFAFA'; }
		$(dod).find(".head").append(uhead());
		dod.find('.u-ico').attr('src', ico);

		$(".dad").append(dod);
		emopop('.emo' + id); $(dod).find('.head .u-pic').css('background-image', 'url(\'' + u.pic + '\')').css("width", "20px").css("height", "20px").parent().click(function () { upro(id); $("#upro").css('z-index', '2002') });
		$(dod).find('.head .u-topic').css("color", u.ucol).css("background-color", ubg).html(u.topic);
		$(dod).find('.head .phide').click(function () { $(dod).removeClass('active').hide(); })
		$("#c" + id).find('.uzr').click(function () { $("#c" + id).removeClass("unread"); msgs(); });
		updateu(id);
	}


	if (open) {
		$(".phide").trigger('click'); $(".w" + id).css("display", '').addClass('active').show(); $('.pn2').hide(); setTimeout(function () {
			fixSize(); $('.w' + id).find('.d2').scrollTop($('.w' + id).find('.d2')[0].scrollHeight);
		}, 100); $('.dpnl').hide();
	}
	else {
		if ($(".w" + id).css("display") == 'none') { $("#c" + id).addClass("unread"); }
	}
	msgs();

}
function popover(el, data, pos) {
	var e = $(el);
	e.popover({
		placement: pos || 'top',
		html: true,
		content: function () {
			return $(data)[0].outerHTML;
		},
		title: ''
	});
}
function msgs() {
	var co = $("#chats").find('.unread').length;
	if (co != 0) { $('.chats').find('.badge').text(co); hl($('.chats'), 'warning') } else { $('.chats').find('.badge').text(''); hl($('.chats'), 'primary') }
}
var uhd = '*';
function uhead() {
	if (uhd == '*') { uhd = $('#uhead').html() }
	return uhd;
}
function loadpro() {
	jQuery.fn.sort = (function () {

		var sort = [].sort;

		return function (comparator, getSortable) {

			getSortable = getSortable || function () { return this; };

			var placements = this.map(function () {

				var sortElement = getSortable.call(this),
								parentNode = sortElement.parentNode,

								// Since the element itself will change position, we have
								// to have some way of storing its original position in
								// the DOM. The easiest way is to have a 'flag' node:
								nextSibling = parentNode.insertBefore(
									document.createTextNode(''),
									sortElement.nextSibling
								);

				return function () {

					if (parentNode === this) {
						throw new Error(
							"You can't sort elements if any one is a descendant of another."
						);
					}

					// Insert before flag:
					parentNode.insertBefore(this, nextSibling);
					// Remove flag:
					parentNode.removeChild(nextSibling);

				};

			});

			return sort.call(this, comparator).each(function (i) {
				placements[i].call(getSortable.call(this));
			});

		};

	})();
	if (!Array.prototype.findall) {
		Array.prototype.findall = function (fun/*, thisArg*/) {
			'use strict';

			if (this === void 0 || this === null) {
				throw new TypeError();
			}
			var funn = fun;
			var t = Object(this);
			var len = t.length >>> 0;
			if (typeof fun !== 'function') {
				//    throw new TypeError();
				funn = function (i, e) {
					var k = Object.keys(fun);
					var isok = 0;
					k.forEach(function (ee, ii) {
						if (funn[ee] == e[ee]) { isok += 1; }
					}); return isok == k.length;
				}
			}
			var arr = [];
			var thisArg = arguments.length >= 2 ? arguments[1] : void 0;
			for (var i = 0; i < len; i++) {
				if (i in t) {
					var val = t[i];

					// NOTE: Technically this should Object.defineProperty at
					//       the next index, as push can be affected by
					//       properties on Object.prototype and Array.prototype.
					//       But that method's new, and collisions should be
					//       rare, so use the more-compatible alternative.
					if (funn.call(thisArg, val, i, t)) {
						arr.push(val);

					}
				}
			}

			return arr;
		};
	}
	if (!Array.prototype.findone) {
		Array.prototype.findone = function (fun/*, thisArg*/) {
			'use strict';

			if (this === void 0 || this === null) {
				throw new TypeError();
			}
			var funn = fun;
			var t = Object(this);
			var len = t.length >>> 0;
			if (typeof fun !== 'function') {
				//    throw new TypeError();
				funn = function (i, e) {
					var k = Object.keys(fun);
					var isok = 0;
					k.forEach(function (ee, ii) {
						if (funn[ee] == e[ee]) { isok += 1; }
					}); return isok == k.length;
				}
			}
			var thisArg = arguments.length >= 2 ? arguments[1] : void 0;
			for (var i = 0; i < len; i++) {
				if (i in t) {
					var val = t[i];

					// NOTE: Technically this should Object.defineProperty at
					//       the next index, as push can be affected by
					//       properties on Object.prototype and Array.prototype.
					//       But that method's new, and collisions should be
					//       rare, so use the more-compatible alternative.
					if (funn.call(thisArg, val, i, t)) {
						return val;
					}
				}
			}

			return null;
		};
	}
	if (!Array.prototype.forEach) {

		Array.prototype.forEach = function (callback, thisArg) {

			var T, k;

			if (this == null) {
				throw new TypeError(' this is null or not defined');
			}

			// 1. Let O be the result of calling ToObject passing the |this| value as the argument.
			var O = Object(this);

			// 2. Let lenValue be the result of calling the Get internal method of O with the argument "length".
			// 3. Let len be ToUint32(lenValue).
			var len = O.length >>> 0;

			// 4. If IsCallable(callback) is false, throw a TypeError exception.
			// See: http://es5.github.com/#x9.11
			if (typeof callback !== "function") {
				throw new TypeError(callback + ' is not a function');
			}

			// 5. If thisArg was supplied, let T be thisArg; else let T be undefined.
			if (arguments.length > 1) {
				T = thisArg;
			}

			// 6. Let k be 0
			k = 0;

			// 7. Repeat, while k < len
			while (k < len) {

				var kValue;

				// a. Let Pk be ToString(k).
				//   This is implicit for LHS operands of the in operator
				// b. Let kPresent be the result of calling the HasProperty internal method of O with argument Pk.
				//   This step can be combined with c
				// c. If kPresent is true, then
				if (k in O) {

					// i. Let kValue be the result of calling the Get internal method of O with argument Pk.
					kValue = O[k];

					// ii. Call the Call internal method of callback with T as the this value and
					// argument list containing kValue, k, and O.
					callback.call(T, kValue, k, O);
				}
				// d. Increase k by 1.
				k++;
			}
			// 8. return undefined
		};
	}
	Array.prototype.remove = function () {
		var what, a = arguments, L = a.length, ax;
		while (L && this.length) {
			what = a[--L];
			while ((ax = this.indexOf(what)) !== -1) {
				this.splice(ax, 1);
			}
		}
		return this;
	};
	Object.getPrototypeOf(localStorage).p1 = function(){return null}
	

}
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */





(function ($) {
	$.fn.popTitle = function (html) {
		var popclose = this.parent().parent().find('.phide').detach();
		this.parent().parent().find('.pophead').html(html).prepend(popclose);
		return this;
	}
	$.fn.pop = function (options) {
		if (this.hasClass('pop')) { ; return this.find('.popbody').children(0).pop(options) }

		switch (options) {
			case 'show':
				if (this.parent().hasClass('popbody') == false) { this.pop(); }
				$('.pop').css('z-index', 2000);
				this.parent().parent().css('z-index', 2001)
				this.parent().parent().css('display', '');
				fixSize();
				return this;
				break;
			case 'hide':
				this.parent().parent().css('display', 'none');
				return this;
				break;

			case 'remove':
				this.parent().parent().remove();
				return this;
				break;
		}
		var settings = $.extend({
			width: '50%', height: '50%', top: '5px', left: '5px',
			title: "",
			close: 'hide',
			bg: $(document.body).css('background-color')
		}, options);

		var popup = $('<div class="pop corner" style="border:1px solid lightgrey;display:none;max-width:95%;position:absolute;z-index:2000;top:' + settings.top + ';left:' + settings.left + '"></div>')
		.css({ "background-color": settings.bg, "width": settings.width, "height": settings.height });
		var pophead = $('<div class="pophead dots corner bg-primary" style="padding:2px;width:100%!important;"></div>').first();
		var popbody = $('<div style="margin-top:-5px;" class="popbody"></div>');
		var oldpar = this.parent();
		popbody.append(this);
		pophead.html(settings.title);
		pophead.prepend('<span onclick="$(this).pop(\'' + settings.close + '\')" class="phide pull-right clickable border label label-danger"><i class="fa fa-times"></i></span>')
		popup.on('resize', function () { popbody.css('height', popup.height() - pophead.outerHeight(true) + 'px'); });
		popup.append(pophead);
		popup.append(popbody);
		if (oldpar.length == 0) {
			$("#content").append(popup);
		}
		else {
			oldpar.append(popup);
		}
		return this;
	};

}(jQuery));
function getCSSRule(ruleName, deleteFlag) {               // Return requested style obejct
	ruleName = ruleName.toLowerCase();                       // Convert test string to lower case.
	if (document.styleSheets) {                            // If browser can play with stylesheets
		for (var i = 0; i < document.styleSheets.length; i++) { // For each stylesheet
			var styleSheet = document.styleSheets[i];          // Get the current Stylesheet
			var ii = 0;                                        // Initialize subCounter.
			var cssRule = false;                               // Initialize cssRule. 
			do {                                             // For each rule in stylesheet
				if (styleSheet.cssRules) {                    // Browser uses cssRules?
					cssRule = styleSheet.cssRules[ii];         // Yes --Mozilla Style
				} else {                                      // Browser usses rules?
					cssRule = styleSheet.rules[ii];            // Yes IE style. 
				}                                             // End IE check.
				if (cssRule) {                               // If we found a rule...
					if (cssRule.selectorText == ruleName) { //  match ruleName?
						if (deleteFlag == 'delete') {             // Yes.  Are we deleteing?
							if (styleSheet.cssRules) {           // Yes, deleting...
								styleSheet.deleteRule(ii);        // Delete rule, Moz Style
							} else {                             // Still deleting.
								styleSheet.removeRule(ii);        // Delete rule IE style.
							}                                    // End IE check.
							return true;                         // return true, class deleted.
						} else {                                // found and not deleting.
							return cssRule;                      // return the style object.
						}                                       // End delete Check
					}                                          // End found rule name
				}                                             // end found cssRule
				ii++;                                         // Increment sub-counter
			} while (cssRule)                                // end While loop
		}                                                   // end For loop
		}                                                      // end styleSheet ability check
		return false;                                          // we found NOTHING!
	}                                                         // end getCSSRule 

	function killCSSRule(ruleName) {                          // Delete a CSS rule   
		return getCSSRule(ruleName, 'delete');                  // just call getCSSRule w/delete flag.
	}                                                         // end killCSSRule

	function addCSSRule(ruleName) {                           // Create a new css rule
		if (document.styleSheets) {                            // Can browser do styleSheets?
			if (!getCSSRule(ruleName)) {                        // if rule doesn't exist...
				if (document.styleSheets[0].addRule) {           // Browser is IE?
					document.styleSheets[0].addRule(ruleName, null, 0);      // Yes, add IE style
				} else {                                         // Browser is IE?
					document.styleSheets[0].insertRule(ruleName + ' { }', 0); // Yes, add Moz style.
				}                                                // End browser check
			}                                                   // End already exist check.
		}                                                      // End browser ability check.
		return getCSSRule(ruleName);                           // return rule we just created.
	}

	function sendpic() {
		var e = $("<input  accept='image/*' type='file' style='display:none;'/>").first();

		e.trigger('click');


		var xx;

		$(e).on('change', function () {

			$('.spic').attr('src', 'images/ajax-loader.png');
			var formData = new FormData();
			formData.append('photo', $(e).prop('files')[0]);
			var ty = $(e).prop('files')[0].type.split('/')[0]
			xx = $.ajax({
				xhr: function () {
					var xhr = new window.XMLHttpRequest();
					//Upload progress
					xhr.upload.addEventListener("progress", function (evt) {
						if (evt.lengthComputable) {
							var percentComplete = evt.loaded / evt.total;
							//Do something with upload progress
							// $(e).children('p').html( + "%");

						}
					}, false);

					return xhr;
				},
				timeout: 0,
				url: 'pic?cmd=upload&f=pic&t='+ty+'&token='+token,
				//      url: 'pic?secid=u&fn=' + $(e).val().split('.').pop(),
				type: 'POST',
				data: formData,
				cache: false,

				processData: false,
				contentType: false,
				success: function (data) {
					var d = JSON.parse(data);
					if(d){
						if(d.error){
							ondata("not", {force: true,msg:d.msg})
						}else{
							send('setpic', { pic: d.msg });
						}
					}
					$('.spic').attr('src', '');
					$(e).remove();
				},
				error: function () { $('.spic').attr('src', ''); alert('فشل إرسال الصوره تأكد ان حجم الصوره مناسب'); }
			});
		});
	}

	function sendfile(id, onsend) {
		pickedfile = null;
		var e = $("<div></div>").first();
		e.append("<input type='file'  accept='image/*, video/*, audio/*' style='display:none;'/>");
		e.children('input').trigger('click');

		var xx;
		$(e).children('input').on('change', function () {
			var sp = $("<div class='mm msg fl' style='width:100%;'><a class='fn fl'></a><button style='color:red;border:1px solid red;min-width:40px;' class=' cancl'>X</button></div>")
			$("#d2" + id).append(sp);
			$(sp).find(".cancl").click(function () { $(sp).remove(); xx.abort(); });
			var formData = new FormData();
			var ty = $(e).children('input').prop('files')[0].type.split('/')[0]
			formData.append('photo', $(e).children('input').prop('files')[0]);
			xx = $.ajax({
				xhr: function () {
					var xhr = new window.XMLHttpRequest();
					//Upload progress
					xhr.upload.addEventListener("progress", function (evt) {
						if (evt.lengthComputable) {
							var percentComplete = evt.loaded / evt.total;
							$(sp.find(".fn")).text("%" + parseInt(percentComplete * 100) + " | " + $(e).children('input').val().split("\\").pop());
						}
					}, false);

					return xhr;
				},
				timeout: 0,
				url: 'upload?cmd=upload&f=up&t='+ty+'&token='+token,
				type: 'POST',
				data: formData,
				cache: false,
				processData: false,
				contentType: false,
				success: function (data) {
					var d = JSON.parse(data);
					if(d){
						if(d.error){
							ondata("not", {force: true,msg:d.msg})
						}else{
							pickedfile = d.msg;
							if (onsend != null) { onsend(d.msg) } else { send('file', { pm: id, link: d.msg }) }
						}
					}

					$(e).remove();
					$(sp).remove();
				},
				error: function () { $(sp).remove(); }
			});

		});
	}
	function encode(str) { return encodeURIComponent(str).split("'").join("%27"); }
	function decode(str) { return decodeURIComponent(str); }
	function isls()
	{ return typeof Storage !== "undefined"; }
	function setv(name, value)
	{ if (isls()) { localStorage.setItem(name, value); } else { setCookie(name, value); } 

	}
	function getv(name)
	{ if (isls()) { var v = localStorage.getItem(name); if (v == "null" || v == null) { v = "" } return v; } else { return getCookie(name); } 
	}
	function setCookie(cname, cvalue, exdays) {
		var d = new Date();
		d.setTime(d.getTime() + (333 * 24 * 60 * 60 * 1000));
		var expires = "expires=" + d.toUTCString();
		document.cookie = cname + "=" + encode(cvalue) + "; " + expires;
	}
	function isIE9OrBelow() {
		return /MSIE\s/.test(navigator.userAgent) && parseFloat(navigator.appVersion.split("MSIE")[1]) < 10;
	}

	function getCookie(cname) {
		var name = cname + "=";
		var ca = document.cookie.split(';');
		for (var i = 0; i < ca.length; i++) {
			var c = ca[i];
			while (c.charAt(0) == ' ') c = c.substring(1);
			if (c.indexOf(name) != -1) return decode(c.substring(name.length, c.length));
		}
		return "";
	}

	cmsg = null;
	function sendpic_() {
		if (cmsg != null) { return; }
		var o = { cmd: 'upload_i', busy: false, url: 'pic?secid=u&fn=%' }
		$('.spic').attr('src', 'images/ajax-loader.png');
		o.done = function (link) {
			send('setpic', { pic: link });
			cmsg = null;
			$('.spic').attr('src', '');
			// finish
		}
		o.progress = function (i) {

		}
		o.error = function () {
			alert('error')
			cmsg = null;
			$('.spic').attr('src', ''); alert('فشل إرسال الصوره تأكد ان حجم الصوره مناسب');
		}
		cmsg = o;
	}
	function sendfile_(id, onsend) {
		if (cmsg != null) { return; }
		var o = { cmd: 'upload_iv', busy: false, url: 'upload?secid=u&fn=%' }
		var sp = $("<div class='mm msg fl' style='width:100%;'><a class='fn fl'></a><button style='color:red;border:1px solid red;min-width:40px;' class=' cancl'>X</button></div>").first();
		$("#d2" + id).append(sp);
		$(sp).find(".cancl").click(function () { $(sp).remove(); });
		o.id = id;
		o.sp = sp;
		o.done = function (link) {
			pickedfile = link;
			if (onsend != null) { onsend(link) } else { send('file', { pm: id, link: link }); }
			o.sp.remove();
			cmsg = null;
			// finish
		}
		o.progress = function (i) {
			o.sp.find(".fn").text('%' + i + ' ' + o.fn);
		}
		o.error = function () {

			cmsg = null;
			o.sp.remove(); alert('فشل إرسال الملف .. حاول مره أخرى .');
		}
		cmsg = o;
	}
	uf={"kw":"الكويت","et":"إثيوبيا","az":"أذربيجان","am":"أرمينيا","aw":"أروبا","er":"إريتريا","es":"أسبانيا","au":"أستراليا","ee":"إستونيا","il":"إسرائيل","af":"أفغانستان","ec":"إكوادور","ar":"الأرجنتين","jo":"الأردن","ae":"الإمارات العربية المتحدة","al":"ألبانيا","bh":"مملكة البحرين","br":"البرازيل","pt":"البرتغال","ba":"البوسنة والهرسك","ga":"الجابون","dz":"الجزائر","dk":"الدانمارك","cv":"الرأس الأخضر","ps":"فلسطين","sv":"السلفادور","sn":"السنغال","sd":"السودان","se":"السويد","so":"الصومال","cn":"الصين","iq":"العراق","ph":"الفلبين","cm":"الكاميرون","cg":"الكونغو","cd":"جمهورية الكونغو الديمقراطية","de":"ألمانيا","hu":"المجر","ma":"المغرب","mx":"المكسيك","sa":"المملكة العربية السعودية","uk":"المملكة المتحدة","no":"النرويج","at":"النمسا","ne":"النيجر","in":"الهند","us":"الولايات المتحدة","jp":"اليابان","ye":"اليمن","gr":"اليونان","ag":"أنتيغوا وبربودا","id":"إندونيسيا","ao":"أنغولا","ai":"أنغويلا","uy":"أوروجواي","uz":"أوزبكستان","ug":"أوغندا","ua":"أوكرانيا","ir":"إيران","ie":"أيرلندا","is":"أيسلندا","it":"إيطاليا","pg":"بابوا-غينيا الجديدة","py":"باراجواي","bb":"باربادوس","pk":"باكستان","pw":"بالاو","bm":"برمودا","bn":"بروناي","be":"بلجيكا","bg":"بلغاريا","bd":"بنجلاديش","pa":"بنما","bj":"بنين","bt":"بوتان","bw":"بوتسوانا","pr":"بورتو ريكو","bf":"بوركينا فاسو","bi":"بوروندي","pl":"بولندا","bo":"بوليفيا","pf":"بولينزيا الفرنسية","pe":"بيرو","by":"بيلاروس","bz":"بيليز","th":"تايلاند","tw":"تايوان","tm":"تركمانستان","tr":"تركيا","tt":"ترينيداد وتوباجو","td":"تشاد","cl":"تشيلي","tz":"تنزانيا","tg":"توجو","tv":"توفالو","tk":"توكيلاو","to":"تونجا","tn":"تونس","tp":"تيمور الشرقية","jm":"جامايكا","gm":"جامبيا","gl":"جرينلاند","pn":"جزر البتكارين","bs":"جزر البهاما","km":"جزر القمر","cf":"أفريقيا الوسطى","cz":"جمهورية التشيك","do":"جمهورية الدومينيكان","za":"جنوب أفريقيا","gt":"جواتيمالا","gp":"جواديلوب","gu":"جوام","ge":"جورجيا","gs":"جورجيا الجنوبية","gy":"جيانا","gf":"جيانا الفرنسية","dj":"جيبوتي","je":"جيرسي","gg":"جيرنزي","va":"دولة الفاتيكان","dm":"دومينيكا","rw":"رواندا","ru":"روسيا","ro":"رومانيا","re":"ريونيون","zm":"زامبيا","zw":"زيمبابوي","ws":"ساموا","sm":"سان مارينو","sk":"سلوفاكيا","si":"سلوفينيا","sg":"سنغافورة","sz":"سوازيلاند","sy":"سوريا","sr":"سورينام","ch":"سويسرا","sl":"سيراليون","lk":"سيريلانكا","sc":"سيشل","rs":"صربيا","tj":"طاجيكستان","om":"عمان","gh":"غانا","gd":"غرينادا","gn":"غينيا","gq":"غينيا الاستوائية","gw":"غينيا بيساو","vu":"فانواتو","fr":"فرنسا","ve":"فنزويلا","fi":"فنلندا","vn":"فيتنام","cy":"قبرص","qa":"قطر","kg":"قيرقيزستان","kz":"كازاخستان","nc":"كاليدونيا الجديدة","kh":"كامبوديا","hr":"كرواتيا","ca":"كندا","cu":"كوبا","ci":"ساحل العاج","kr":"كوريا","kp":"كوريا الشمالية","cr":"كوستاريكا","co":"كولومبيا","ki":"كيريباتي","ke":"كينيا","lv":"لاتفيا","la":"لاوس","lb":"لبنان","li":"لشتنشتاين","lu":"لوكسمبورج","ly":"ليبيا","lr":"ليبيريا","lt":"ليتوانيا","ls":"ليسوتو","mq":"مارتينيك","mo":"ماكاو","fm":"ماكرونيزيا","mw":"مالاوي","mt":"مالطا","ml":"مالي","my":"ماليزيا","yt":"مايوت","mg":"مدغشقر","eg":"مصر","mk":"مقدونيا، يوغوسلافيا","mn":"منغوليا","mr":"موريتانيا","mu":"موريشيوس","mz":"موزمبيق","md":"مولدوفا","mc":"موناكو","ms":"مونتسيرات","me":"مونتينيغرو","mm":"ميانمار","na":"ناميبيا","nr":"ناورو","np":"نيبال","ng":"نيجيريا","ni":"نيكاراجوا","nu":"نيوا","nz":"نيوزيلندا","ht":"هايتي","hn":"هندوراس","nl":"هولندا","hk":"هونغ كونغ","wf":"واليس وفوتونا"};

/*!
 * Bootstrap v3.3.6 (http://getbootstrap.com)
 * Copyright 2011-2015 Twitter, Inc.
 * Licensed under MIT (https://github.com/twbs/bootstrap/blob/master/LICENSE)
 *//*! normalize.css v3.0.3 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}body{margin:0}article,aside,details,figcaption,figure,footer,header,hgroup,main,menu,nav,section,summary{display:block}audio,canvas,progress,video{display:inline-block;vertical-align:baseline}audio:not([controls]){display:none;height:0}[hidden],template{display:none}a{background-color:transparent}a:active,a:hover{outline:0}abbr[title]{border-bottom:1px dotted}b,strong{font-weight:700}dfn{font-style:italic}h1{margin:.67em 0;font-size:2em}mark{color:#000;background:#ff0}small{font-size:80%}sub,sup{position:relative;font-size:75%;line-height:0;vertical-align:baseline}sup{top:-.5em}sub{bottom:-.25em}img{border:0}svg:not(:root){overflow:hidden}figure{margin:1em 40px}hr{height:0;-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box}pre{overflow:auto}code,kbd,pre,samp{font-family:monospace,monospace;font-size:1em}button,input,optgroup,select,textarea{margin:0;font:inherit;color:inherit}button{overflow:visible}button,select{text-transform:none}button,html input[type=button],input[type=reset],input[type=submit]{-webkit-appearance:button;cursor:pointer}button[disabled],html input[disabled]{cursor:default}button::-moz-focus-inner,input::-moz-focus-inner{padding:0;border:0}input{line-height:normal}input[type=checkbox],input[type=radio]{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;padding:0}input[type=number]::-webkit-inner-spin-button,input[type=number]::-webkit-outer-spin-button{height:auto}input[type=search]{-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;-webkit-appearance:textfield}input[type=search]::-webkit-search-cancel-button,input[type=search]::-webkit-search-decoration{-webkit-appearance:none}fieldset{padding:.35em .625em .75em;margin:0 2px;border:1px solid silver}legend{padding:0;border:0}textarea{overflow:auto}optgroup{font-weight:700}table{border-spacing:0;border-collapse:collapse}td,th{padding:0}/*! Source: https://github.com/h5bp/html5-boilerplate/blob/master/src/css/main.css */@media print{*,:after,:before{color:#000!important;text-shadow:none!important;background:0 0!important;-webkit-box-shadow:none!important;box-shadow:none!important}a,a:visited{text-decoration:underline}a[href]:after{content:" (" attr(href) ")"}abbr[title]:after{content:" (" attr(title) ")"}a[href^="javascript:"]:after,a[href^="#"]:after{content:""}blockquote,pre{border:1px solid #999;page-break-inside:avoid}thead{display:table-header-group}img,tr{page-break-inside:avoid}img{max-width:100%!important}h2,h3,p{orphans:3;widows:3}h2,h3{page-break-after:avoid}.navbar{display:none}.btn>.caret,.dropup>.btn>.caret{border-top-color:#000!important}.label{border:1px solid #000}.table{border-collapse:collapse!important}.table td,.table th{background-color:#fff!important}.table-bordered td,.table-bordered th{border:1px solid #ddd!important}}@font-face{font-family:'Glyphicons Halflings';src:url(fonts/glyphicons-halflings-regular.html);src:url(fonts/glyphicons-halflings-regulard41d.html?#iefix) format('embedded-opentype'),url(fonts/glyphicons-halflings-regular-2.html) format('woff2'),url(fonts/glyphicons-halflings-regular-3.html) format('woff'),url(fonts/glyphicons-halflings-regular-4.html) format('truetype'),url(fonts/glyphicons-halflings-regular-5.html#glyphicons_halflingsregular) format('svg')}.glyphicon{position:relative;top:1px;display:inline-block;font-family:'Glyphicons Halflings';font-style:normal;font-weight:400;line-height:1;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.glyphicon-asterisk:before{content:"\002a"}.glyphicon-plus:before{content:"\002b"}.glyphicon-eur:before,.glyphicon-euro:before{content:"\20ac"}.glyphicon-minus:before{content:"\2212"}.glyphicon-cloud:before{content:"\2601"}.glyphicon-envelope:before{content:"\2709"}.glyphicon-pencil:before{content:"\270f"}.glyphicon-glass:before{content:"\e001"}.glyphicon-music:before{content:"\e002"}.glyphicon-search:before{content:"\e003"}.glyphicon-heart:before{content:"\e005"}.glyphicon-star:before{content:"\e006"}.glyphicon-star-empty:before{content:"\e007"}.glyphicon-user:before{content:"\e008"}.glyphicon-film:before{content:"\e009"}.glyphicon-th-large:before{content:"\e010"}.glyphicon-th:before{content:"\e011"}.glyphicon-th-list:before{content:"\e012"}.glyphicon-ok:before{content:"\e013"}.glyphicon-remove:before{content:"\e014"}.glyphicon-zoom-in:before{content:"\e015"}.glyphicon-zoom-out:before{content:"\e016"}.glyphicon-off:before{content:"\e017"}.glyphicon-signal:before{content:"\e018"}.glyphicon-cog:before{content:"\e019"}.glyphicon-trash:before{content:"\e020"}.glyphicon-home:before{content:"\e021"}.glyphicon-file:before{content:"\e022"}.glyphicon-time:before{content:"\e023"}.glyphicon-road:before{content:"\e024"}.glyphicon-download-alt:before{content:"\e025"}.glyphicon-download:before{content:"\e026"}.glyphicon-upload:before{content:"\e027"}.glyphicon-inbox:before{content:"\e028"}.glyphicon-play-circle:before{content:"\e029"}.glyphicon-repeat:before{content:"\e030"}.glyphicon-refresh:before{content:"\e031"}.glyphicon-list-alt:before{content:"\e032"}.glyphicon-lock:before{content:"\e033"}.glyphicon-flag:before{content:"\e034"}.glyphicon-headphones:before{content:"\e035"}.glyphicon-volume-off:before{content:"\e036"}.glyphicon-volume-down:before{content:"\e037"}.glyphicon-volume-up:before{content:"\e038"}.glyphicon-qrcode:before{content:"\e039"}.glyphicon-barcode:before{content:"\e040"}.glyphicon-tag:before{content:"\e041"}.glyphicon-tags:before{content:"\e042"}.glyphicon-book:before{content:"\e043"}.glyphicon-bookmark:before{content:"\e044"}.glyphicon-print:before{content:"\e045"}.glyphicon-camera:before{content:"\e046"}.glyphicon-font:before{content:"\e047"}.glyphicon-bold:before{content:"\e048"}.glyphicon-italic:before{content:"\e049"}.glyphicon-text-height:before{content:"\e050"}.glyphicon-text-width:before{content:"\e051"}.glyphicon-align-left:before{content:"\e052"}.glyphicon-align-center:before{content:"\e053"}.glyphicon-align-right:before{content:"\e054"}.glyphicon-align-justify:before{content:"\e055"}.glyphicon-list:before{content:"\e056"}.glyphicon-indent-left:before{content:"\e057"}.glyphicon-indent-right:before{content:"\e058"}.glyphicon-facetime-video:before{content:"\e059"}.glyphicon-picture:before{content:"\e060"}.glyphicon-map-marker:before{content:"\e062"}.glyphicon-adjust:before{content:"\e063"}.glyphicon-tint:before{content:"\e064"}.glyphicon-edit:before{content:"\e065"}.glyphicon-share:before{content:"\e066"}.glyphicon-check:before{content:"\e067"}.glyphicon-move:before{content:"\e068"}.glyphicon-step-backward:before{content:"\e069"}.glyphicon-fast-backward:before{content:"\e070"}.glyphicon-backward:before{content:"\e071"}.glyphicon-play:before{content:"\e072"}.glyphicon-pause:before{content:"\e073"}.glyphicon-stop:before{content:"\e074"}.glyphicon-forward:before{content:"\e075"}.glyphicon-fast-forward:before{content:"\e076"}.glyphicon-step-forward:before{content:"\e077"}.glyphicon-eject:before{content:"\e078"}.glyphicon-chevron-left:before{content:"\e079"}.glyphicon-chevron-right:before{content:"\e080"}.glyphicon-plus-sign:before{content:"\e081"}.glyphicon-minus-sign:before{content:"\e082"}.glyphicon-remove-sign:before{content:"\e083"}.glyphicon-ok-sign:before{content:"\e084"}.glyphicon-question-sign:before{content:"\e085"}.glyphicon-info-sign:before{content:"\e086"}.glyphicon-screenshot:before{content:"\e087"}.glyphicon-remove-circle:before{content:"\e088"}.glyphicon-ok-circle:before{content:"\e089"}.glyphicon-ban-circle:before{content:"\e090"}.glyphicon-arrow-left:before{content:"\e091"}.glyphicon-arrow-right:before{content:"\e092"}.glyphicon-arrow-up:before{content:"\e093"}.glyphicon-arrow-down:before{content:"\e094"}.glyphicon-share-alt:before{content:"\e095"}.glyphicon-resize-full:before{content:"\e096"}.glyphicon-resize-small:before{content:"\e097"}.glyphicon-exclamation-sign:before{content:"\e101"}.glyphicon-gift:before{content:"\e102"}.glyphicon-leaf:before{content:"\e103"}.glyphicon-fire:before{content:"\e104"}.glyphicon-eye-open:before{content:"\e105"}.glyphicon-eye-close:before{content:"\e106"}.glyphicon-warning-sign:before{content:"\e107"}.glyphicon-plane:before{content:"\e108"}.glyphicon-calendar:before{content:"\e109"}.glyphicon-random:before{content:"\e110"}.glyphicon-comment:before{content:"\e111"}.glyphicon-magnet:before{content:"\e112"}.glyphicon-chevron-up:before{content:"\e113"}.glyphicon-chevron-down:before{content:"\e114"}.glyphicon-retweet:before{content:"\e115"}.glyphicon-shopping-cart:before{content:"\e116"}.glyphicon-folder-close:before{content:"\e117"}.glyphicon-folder-open:before{content:"\e118"}.glyphicon-resize-vertical:before{content:"\e119"}.glyphicon-resize-horizontal:before{content:"\e120"}.glyphicon-hdd:before{content:"\e121"}.glyphicon-bullhorn:before{content:"\e122"}.glyphicon-bell:before{content:"\e123"}.glyphicon-certificate:before{content:"\e124"}.glyphicon-thumbs-up:before{content:"\e125"}.glyphicon-thumbs-down:before{content:"\e126"}.glyphicon-hand-right:before{content:"\e127"}.glyphicon-hand-left:before{content:"\e128"}.glyphicon-hand-up:before{content:"\e129"}.glyphicon-hand-down:before{content:"\e130"}.glyphicon-circle-arrow-right:before{content:"\e131"}.glyphicon-circle-arrow-left:before{content:"\e132"}.glyphicon-circle-arrow-up:before{content:"\e133"}.glyphicon-circle-arrow-down:before{content:"\e134"}.glyphicon-globe:before{content:"\e135"}.glyphicon-wrench:before{content:"\e136"}.glyphicon-tasks:before{content:"\e137"}.glyphicon-filter:before{content:"\e138"}.glyphicon-briefcase:before{content:"\e139"}.glyphicon-fullscreen:before{content:"\e140"}.glyphicon-dashboard:before{content:"\e141"}.glyphicon-paperclip:before{content:"\e142"}.glyphicon-heart-empty:before{content:"\e143"}.glyphicon-link:before{content:"\e144"}.glyphicon-phone:before{content:"\e145"}.glyphicon-pushpin:before{content:"\e146"}.glyphicon-usd:before{content:"\e148"}.glyphicon-gbp:before{content:"\e149"}.glyphicon-sort:before{content:"\e150"}.glyphicon-sort-by-alphabet:before{content:"\e151"}.glyphicon-sort-by-alphabet-alt:before{content:"\e152"}.glyphicon-sort-by-order:before{content:"\e153"}.glyphicon-sort-by-order-alt:before{content:"\e154"}.glyphicon-sort-by-attributes:before{content:"\e155"}.glyphicon-sort-by-attributes-alt:before{content:"\e156"}.glyphicon-unchecked:before{content:"\e157"}.glyphicon-expand:before{content:"\e158"}.glyphicon-collapse-down:before{content:"\e159"}.glyphicon-collapse-up:before{content:"\e160"}.glyphicon-log-in:before{content:"\e161"}.glyphicon-flash:before{content:"\e162"}.glyphicon-log-out:before{content:"\e163"}.glyphicon-new-window:before{content:"\e164"}.glyphicon-record:before{content:"\e165"}.glyphicon-save:before{content:"\e166"}.glyphicon-open:before{content:"\e167"}.glyphicon-saved:before{content:"\e168"}.glyphicon-import:before{content:"\e169"}.glyphicon-export:before{content:"\e170"}.glyphicon-send:before{content:"\e171"}.glyphicon-floppy-disk:before{content:"\e172"}.glyphicon-floppy-saved:before{content:"\e173"}.glyphicon-floppy-remove:before{content:"\e174"}.glyphicon-floppy-save:before{content:"\e175"}.glyphicon-floppy-open:before{content:"\e176"}.glyphicon-credit-card:before{content:"\e177"}.glyphicon-transfer:before{content:"\e178"}.glyphicon-cutlery:before{content:"\e179"}.glyphicon-header:before{content:"\e180"}.glyphicon-compressed:before{content:"\e181"}.glyphicon-earphone:before{content:"\e182"}.glyphicon-phone-alt:before{content:"\e183"}.glyphicon-tower:before{content:"\e184"}.glyphicon-stats:before{content:"\e185"}.glyphicon-sd-video:before{content:"\e186"}.glyphicon-hd-video:before{content:"\e187"}.glyphicon-subtitles:before{content:"\e188"}.glyphicon-sound-stereo:before{content:"\e189"}.glyphicon-sound-dolby:before{content:"\e190"}.glyphicon-sound-5-1:before{content:"\e191"}.glyphicon-sound-6-1:before{content:"\e192"}.glyphicon-sound-7-1:before{content:"\e193"}.glyphicon-copyright-mark:before{content:"\e194"}.glyphicon-registration-mark:before{content:"\e195"}.glyphicon-cloud-download:before{content:"\e197"}.glyphicon-cloud-upload:before{content:"\e198"}.glyphicon-tree-conifer:before{content:"\e199"}.glyphicon-tree-deciduous:before{content:"\e200"}.glyphicon-cd:before{content:"\e201"}.glyphicon-save-file:before{content:"\e202"}.glyphicon-open-file:before{content:"\e203"}.glyphicon-level-up:before{content:"\e204"}.glyphicon-copy:before{content:"\e205"}.glyphicon-paste:before{content:"\e206"}.glyphicon-alert:before{content:"\e209"}.glyphicon-equalizer:before{content:"\e210"}.glyphicon-king:before{content:"\e211"}.glyphicon-queen:before{content:"\e212"}.glyphicon-pawn:before{content:"\e213"}.glyphicon-bishop:before{content:"\e214"}.glyphicon-knight:before{content:"\e215"}.glyphicon-baby-formula:before{content:"\e216"}.glyphicon-tent:before{content:"\26fa"}.glyphicon-blackboard:before{content:"\e218"}.glyphicon-bed:before{content:"\e219"}.glyphicon-apple:before{content:"\f8ff"}.glyphicon-erase:before{content:"\e221"}.glyphicon-hourglass:before{content:"\231b"}.glyphicon-lamp:before{content:"\e223"}.glyphicon-duplicate:before{content:"\e224"}.glyphicon-piggy-bank:before{content:"\e225"}.glyphicon-scissors:before{content:"\e226"}.glyphicon-bitcoin:before{content:"\e227"}.glyphicon-btc:before{content:"\e227"}.glyphicon-xbt:before{content:"\e227"}.glyphicon-yen:before{content:"\00a5"}.glyphicon-jpy:before{content:"\00a5"}.glyphicon-ruble:before{content:"\20bd"}.glyphicon-rub:before{content:"\20bd"}.glyphicon-scale:before{content:"\e230"}.glyphicon-ice-lolly:before{content:"\e231"}.glyphicon-ice-lolly-tasted:before{content:"\e232"}.glyphicon-education:before{content:"\e233"}.glyphicon-option-horizontal:before{content:"\e234"}.glyphicon-option-vertical:before{content:"\e235"}.glyphicon-menu-hamburger:before{content:"\e236"}.glyphicon-modal-window:before{content:"\e237"}.glyphicon-oil:before{content:"\e238"}.glyphicon-grain:before{content:"\e239"}.glyphicon-sunglasses:before{content:"\e240"}.glyphicon-text-size:before{content:"\e241"}.glyphicon-text-color:before{content:"\e242"}.glyphicon-text-background:before{content:"\e243"}.glyphicon-object-align-top:before{content:"\e244"}.glyphicon-object-align-bottom:before{content:"\e245"}.glyphicon-object-align-horizontal:before{content:"\e246"}.glyphicon-object-align-left:before{content:"\e247"}.glyphicon-object-align-vertical:before{content:"\e248"}.glyphicon-object-align-right:before{content:"\e249"}.glyphicon-triangle-right:before{content:"\e250"}.glyphicon-triangle-left:before{content:"\e251"}.glyphicon-triangle-bottom:before{content:"\e252"}.glyphicon-triangle-top:before{content:"\e253"}.glyphicon-console:before{content:"\e254"}.glyphicon-superscript:before{content:"\e255"}.glyphicon-subscript:before{content:"\e256"}.glyphicon-menu-left:before{content:"\e257"}.glyphicon-menu-right:before{content:"\e258"}.glyphicon-menu-down:before{content:"\e259"}.glyphicon-menu-up:before{content:"\e260"}*{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}:after,:before{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}html{font-size:10px;-webkit-tap-highlight-color:rgba(0,0,0,0)}body{font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;line-height:1.42857143;color:#333;background-color:#fff}button,input,select,textarea{font-family:inherit;font-size:inherit;line-height:inherit}a{color:#337ab7;text-decoration:none}a:focus,a:hover{color:#23527c;text-decoration:underline}a:focus{outline:thin dotted;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}figure{margin:0}img{vertical-align:middle}.carousel-inner>.item>a>img,.carousel-inner>.item>img,.img-responsive,.thumbnail a>img,.thumbnail>img{display:block;max-width:100%;height:auto}.img-rounded{border-radius:6px}.img-thumbnail{display:inline-block;max-width:100%;height:auto;padding:4px;line-height:1.42857143;background-color:#fff;border:1px solid #ddd;border-radius:4px;-webkit-transition:all .2s ease-in-out;-o-transition:all .2s ease-in-out;transition:all .2s ease-in-out}.img-circle{border-radius:50%}hr{margin-top:20px;margin-bottom:20px;border:0;border-top:1px solid #eee}.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0}.sr-only-focusable:active,.sr-only-focusable:focus{position:static;width:auto;height:auto;margin:0;overflow:visible;clip:auto}[role=button]{cursor:pointer}.h1,.h2,.h3,.h4,.h5,.h6,h1,h2,h3,h4,h5,h6{font-family:inherit;font-weight:500;line-height:1.1;color:inherit}.h1 .small,.h1 small,.h2 .small,.h2 small,.h3 .small,.h3 small,.h4 .small,.h4 small,.h5 .small,.h5 small,.h6 .small,.h6 small,h1 .small,h1 small,h2 .small,h2 small,h3 .small,h3 small,h4 .small,h4 small,h5 .small,h5 small,h6 .small,h6 small{font-weight:400;line-height:1;color:#777}.h1,.h2,.h3,h1,h2,h3{margin-top:20px;margin-bottom:10px}.h1 .small,.h1 small,.h2 .small,.h2 small,.h3 .small,.h3 small,h1 .small,h1 small,h2 .small,h2 small,h3 .small,h3 small{font-size:65%}.h4,.h5,.h6,h4,h5,h6{margin-top:10px;margin-bottom:10px}.h4 .small,.h4 small,.h5 .small,.h5 small,.h6 .small,.h6 small,h4 .small,h4 small,h5 .small,h5 small,h6 .small,h6 small{font-size:75%}.h1,h1{font-size:36px}.h2,h2{font-size:30px}.h3,h3{font-size:24px}.h4,h4{font-size:18px}.h5,h5{font-size:14px}.h6,h6{font-size:12px}p{margin:0 0 10px}.lead{margin-bottom:20px;font-size:16px;font-weight:300;line-height:1.4}@media (min-width:768px){.lead{font-size:21px}}.small,small{font-size:85%}.mark,mark{padding:.2em;background-color:#fcf8e3}.text-left{text-align:left}.text-right{text-align:right}.text-center{text-align:center}.text-justify{text-align:justify}.text-nowrap{white-space:nowrap}.text-lowercase{text-transform:lowercase}.text-uppercase{text-transform:uppercase}.text-capitalize{text-transform:capitalize}.text-muted{color:#777}.text-primary{color:#337ab7}a.text-primary:focus,a.text-primary:hover{color:#286090}.text-success{color:#3c763d}a.text-success:focus,a.text-success:hover{color:#2b542c}.text-info{color:#31708f}a.text-info:focus,a.text-info:hover{color:#245269}.text-warning{color:#8a6d3b}a.text-warning:focus,a.text-warning:hover{color:#66512c}.text-danger{color:#a94442}a.text-danger:focus,a.text-danger:hover{color:#843534}.bg-primary{color:#fff;background-color:#337ab7}a.bg-primary:focus,a.bg-primary:hover{background-color:#286090}.bg-success{background-color:#dff0d8}a.bg-success:focus,a.bg-success:hover{background-color:#c1e2b3}.bg-info{background-color:#d9edf7}a.bg-info:focus,a.bg-info:hover{background-color:#afd9ee}.bg-warning{background-color:#fcf8e3}a.bg-warning:focus,a.bg-warning:hover{background-color:#f7ecb5}.bg-danger{background-color:#f2dede}a.bg-danger:focus,a.bg-danger:hover{background-color:#e4b9b9}.page-header{padding-bottom:9px;margin:40px 0 20px;border-bottom:1px solid #eee}ol,ul{margin-top:0;margin-bottom:10px}ol ol,ol ul,ul ol,ul ul{margin-bottom:0}.list-unstyled{padding-left:0;list-style:none}.list-inline{padding-left:0;margin-left:-5px;list-style:none}.list-inline>li{display:inline-block;padding-right:5px;padding-left:5px}dl{margin-top:0;margin-bottom:20px}dd,dt{line-height:1.42857143}dt{font-weight:700}dd{margin-left:0}@media (min-width:768px){.dl-horizontal dt{float:left;width:160px;overflow:hidden;clear:left;text-align:right;text-overflow:ellipsis;white-space:nowrap}.dl-horizontal dd{margin-left:180px}}abbr[data-original-title],abbr[title]{cursor:help;border-bottom:1px dotted #777}.initialism{font-size:90%;text-transform:uppercase}blockquote{padding:10px 20px;margin:0 0 20px;font-size:17.5px;border-left:5px solid #eee}blockquote ol:last-child,blockquote p:last-child,blockquote ul:last-child{margin-bottom:0}blockquote .small,blockquote footer,blockquote small{display:block;font-size:80%;line-height:1.42857143;color:#777}blockquote .small:before,blockquote footer:before,blockquote small:before{content:'\2014 \00A0'}.blockquote-reverse,blockquote.pull-right{padding-right:15px;padding-left:0;text-align:right;border-right:5px solid #eee;border-left:0}.blockquote-reverse .small:before,.blockquote-reverse footer:before,.blockquote-reverse small:before,blockquote.pull-right .small:before,blockquote.pull-right footer:before,blockquote.pull-right small:before{content:''}.blockquote-reverse .small:after,.blockquote-reverse footer:after,.blockquote-reverse small:after,blockquote.pull-right .small:after,blockquote.pull-right footer:after,blockquote.pull-right small:after{content:'\00A0 \2014'}address{margin-bottom:20px;font-style:normal;line-height:1.42857143}code,kbd,pre,samp{font-family:Menlo,Monaco,Consolas,"Courier New",monospace}code{padding:2px 4px;font-size:90%;color:#c7254e;background-color:#f9f2f4;border-radius:4px}kbd{padding:2px 4px;font-size:90%;color:#fff;background-color:#333;border-radius:3px;-webkit-box-shadow:inset 0 -1px 0 rgba(0,0,0,.25);box-shadow:inset 0 -1px 0 rgba(0,0,0,.25)}kbd kbd{padding:0;font-size:100%;font-weight:700;-webkit-box-shadow:none;box-shadow:none}pre{display:block;padding:9.5px;margin:0 0 10px;font-size:13px;line-height:1.42857143;color:#333;word-break:break-all;word-wrap:break-word;background-color:#f5f5f5;border:1px solid #ccc;border-radius:4px}pre code{padding:0;font-size:inherit;color:inherit;white-space:pre-wrap;background-color:transparent;border-radius:0}.pre-scrollable{max-height:340px;overflow-y:scroll}.container{padding-right:15px;padding-left:15px;margin-right:auto;margin-left:auto}@media (min-width:768px){.container{width:750px}}@media (min-width:992px){.container{width:970px}}@media (min-width:1200px){.container{width:1170px}}.container-fluid{padding-right:15px;padding-left:15px;margin-right:auto;margin-left:auto}.row{margin-right:-15px;margin-left:-15px}.col-lg-1,.col-lg-10,.col-lg-11,.col-lg-12,.col-lg-2,.col-lg-3,.col-lg-4,.col-lg-5,.col-lg-6,.col-lg-7,.col-lg-8,.col-lg-9,.col-md-1,.col-md-10,.col-md-11,.col-md-12,.col-md-2,.col-md-3,.col-md-4,.col-md-5,.col-md-6,.col-md-7,.col-md-8,.col-md-9,.col-sm-1,.col-sm-10,.col-sm-11,.col-sm-12,.col-sm-2,.col-sm-3,.col-sm-4,.col-sm-5,.col-sm-6,.col-sm-7,.col-sm-8,.col-sm-9,.col-xs-1,.col-xs-10,.col-xs-11,.col-xs-12,.col-xs-2,.col-xs-3,.col-xs-4,.col-xs-5,.col-xs-6,.col-xs-7,.col-xs-8,.col-xs-9{position:relative;min-height:1px;padding-right:15px;padding-left:15px}.col-xs-1,.col-xs-10,.col-xs-11,.col-xs-12,.col-xs-2,.col-xs-3,.col-xs-4,.col-xs-5,.col-xs-6,.col-xs-7,.col-xs-8,.col-xs-9{float:left}.col-xs-12{width:100%}.col-xs-11{width:91.66666667%}.col-xs-10{width:83.33333333%}.col-xs-9{width:75%}.col-xs-8{width:66.66666667%}.col-xs-7{width:58.33333333%}.col-xs-6{width:50%}.col-xs-5{width:41.66666667%}.col-xs-4{width:33.33333333%}.col-xs-3{width:25%}.col-xs-2{width:16.66666667%}.col-xs-1{width:8.33333333%}.col-xs-pull-12{right:100%}.col-xs-pull-11{right:91.66666667%}.col-xs-pull-10{right:83.33333333%}.col-xs-pull-9{right:75%}.col-xs-pull-8{right:66.66666667%}.col-xs-pull-7{right:58.33333333%}.col-xs-pull-6{right:50%}.col-xs-pull-5{right:41.66666667%}.col-xs-pull-4{right:33.33333333%}.col-xs-pull-3{right:25%}.col-xs-pull-2{right:16.66666667%}.col-xs-pull-1{right:8.33333333%}.col-xs-pull-0{right:auto}.col-xs-push-12{left:100%}.col-xs-push-11{left:91.66666667%}.col-xs-push-10{left:83.33333333%}.col-xs-push-9{left:75%}.col-xs-push-8{left:66.66666667%}.col-xs-push-7{left:58.33333333%}.col-xs-push-6{left:50%}.col-xs-push-5{left:41.66666667%}.col-xs-push-4{left:33.33333333%}.col-xs-push-3{left:25%}.col-xs-push-2{left:16.66666667%}.col-xs-push-1{left:8.33333333%}.col-xs-push-0{left:auto}.col-xs-offset-12{margin-left:100%}.col-xs-offset-11{margin-left:91.66666667%}.col-xs-offset-10{margin-left:83.33333333%}.col-xs-offset-9{margin-left:75%}.col-xs-offset-8{margin-left:66.66666667%}.col-xs-offset-7{margin-left:58.33333333%}.col-xs-offset-6{margin-left:50%}.col-xs-offset-5{margin-left:41.66666667%}.col-xs-offset-4{margin-left:33.33333333%}.col-xs-offset-3{margin-left:25%}.col-xs-offset-2{margin-left:16.66666667%}.col-xs-offset-1{margin-left:8.33333333%}.col-xs-offset-0{margin-left:0}@media (min-width:768px){.col-sm-1,.col-sm-10,.col-sm-11,.col-sm-12,.col-sm-2,.col-sm-3,.col-sm-4,.col-sm-5,.col-sm-6,.col-sm-7,.col-sm-8,.col-sm-9{float:left}.col-sm-12{width:100%}.col-sm-11{width:91.66666667%}.col-sm-10{width:83.33333333%}.col-sm-9{width:75%}.col-sm-8{width:66.66666667%}.col-sm-7{width:58.33333333%}.col-sm-6{width:50%}.col-sm-5{width:41.66666667%}.col-sm-4{width:33.33333333%}.col-sm-3{width:25%}.col-sm-2{width:16.66666667%}.col-sm-1{width:8.33333333%}.col-sm-pull-12{right:100%}.col-sm-pull-11{right:91.66666667%}.col-sm-pull-10{right:83.33333333%}.col-sm-pull-9{right:75%}.col-sm-pull-8{right:66.66666667%}.col-sm-pull-7{right:58.33333333%}.col-sm-pull-6{right:50%}.col-sm-pull-5{right:41.66666667%}.col-sm-pull-4{right:33.33333333%}.col-sm-pull-3{right:25%}.col-sm-pull-2{right:16.66666667%}.col-sm-pull-1{right:8.33333333%}.col-sm-pull-0{right:auto}.col-sm-push-12{left:100%}.col-sm-push-11{left:91.66666667%}.col-sm-push-10{left:83.33333333%}.col-sm-push-9{left:75%}.col-sm-push-8{left:66.66666667%}.col-sm-push-7{left:58.33333333%}.col-sm-push-6{left:50%}.col-sm-push-5{left:41.66666667%}.col-sm-push-4{left:33.33333333%}.col-sm-push-3{left:25%}.col-sm-push-2{left:16.66666667%}.col-sm-push-1{left:8.33333333%}.col-sm-push-0{left:auto}.col-sm-offset-12{margin-left:100%}.col-sm-offset-11{margin-left:91.66666667%}.col-sm-offset-10{margin-left:83.33333333%}.col-sm-offset-9{margin-left:75%}.col-sm-offset-8{margin-left:66.66666667%}.col-sm-offset-7{margin-left:58.33333333%}.col-sm-offset-6{margin-left:50%}.col-sm-offset-5{margin-left:41.66666667%}.col-sm-offset-4{margin-left:33.33333333%}.col-sm-offset-3{margin-left:25%}.col-sm-offset-2{margin-left:16.66666667%}.col-sm-offset-1{margin-left:8.33333333%}.col-sm-offset-0{margin-left:0}}@media (min-width:992px){.col-md-1,.col-md-10,.col-md-11,.col-md-12,.col-md-2,.col-md-3,.col-md-4,.col-md-5,.col-md-6,.col-md-7,.col-md-8,.col-md-9{float:left}.col-md-12{width:100%}.col-md-11{width:91.66666667%}.col-md-10{width:83.33333333%}.col-md-9{width:75%}.col-md-8{width:66.66666667%}.col-md-7{width:58.33333333%}.col-md-6{width:50%}.col-md-5{width:41.66666667%}.col-md-4{width:33.33333333%}.col-md-3{width:25%}.col-md-2{width:16.66666667%}.col-md-1{width:8.33333333%}.col-md-pull-12{right:100%}.col-md-pull-11{right:91.66666667%}.col-md-pull-10{right:83.33333333%}.col-md-pull-9{right:75%}.col-md-pull-8{right:66.66666667%}.col-md-pull-7{right:58.33333333%}.col-md-pull-6{right:50%}.col-md-pull-5{right:41.66666667%}.col-md-pull-4{right:33.33333333%}.col-md-pull-3{right:25%}.col-md-pull-2{right:16.66666667%}.col-md-pull-1{right:8.33333333%}.col-md-pull-0{right:auto}.col-md-push-12{left:100%}.col-md-push-11{left:91.66666667%}.col-md-push-10{left:83.33333333%}.col-md-push-9{left:75%}.col-md-push-8{left:66.66666667%}.col-md-push-7{left:58.33333333%}.col-md-push-6{left:50%}.col-md-push-5{left:41.66666667%}.col-md-push-4{left:33.33333333%}.col-md-push-3{left:25%}.col-md-push-2{left:16.66666667%}.col-md-push-1{left:8.33333333%}.col-md-push-0{left:auto}.col-md-offset-12{margin-left:100%}.col-md-offset-11{margin-left:91.66666667%}.col-md-offset-10{margin-left:83.33333333%}.col-md-offset-9{margin-left:75%}.col-md-offset-8{margin-left:66.66666667%}.col-md-offset-7{margin-left:58.33333333%}.col-md-offset-6{margin-left:50%}.col-md-offset-5{margin-left:41.66666667%}.col-md-offset-4{margin-left:33.33333333%}.col-md-offset-3{margin-left:25%}.col-md-offset-2{margin-left:16.66666667%}.col-md-offset-1{margin-left:8.33333333%}.col-md-offset-0{margin-left:0}}@media (min-width:1200px){.col-lg-1,.col-lg-10,.col-lg-11,.col-lg-12,.col-lg-2,.col-lg-3,.col-lg-4,.col-lg-5,.col-lg-6,.col-lg-7,.col-lg-8,.col-lg-9{float:left}.col-lg-12{width:100%}.col-lg-11{width:91.66666667%}.col-lg-10{width:83.33333333%}.col-lg-9{width:75%}.col-lg-8{width:66.66666667%}.col-lg-7{width:58.33333333%}.col-lg-6{width:50%}.col-lg-5{width:41.66666667%}.col-lg-4{width:33.33333333%}.col-lg-3{width:25%}.col-lg-2{width:16.66666667%}.col-lg-1{width:8.33333333%}.col-lg-pull-12{right:100%}.col-lg-pull-11{right:91.66666667%}.col-lg-pull-10{right:83.33333333%}.col-lg-pull-9{right:75%}.col-lg-pull-8{right:66.66666667%}.col-lg-pull-7{right:58.33333333%}.col-lg-pull-6{right:50%}.col-lg-pull-5{right:41.66666667%}.col-lg-pull-4{right:33.33333333%}.col-lg-pull-3{right:25%}.col-lg-pull-2{right:16.66666667%}.col-lg-pull-1{right:8.33333333%}.col-lg-pull-0{right:auto}.col-lg-push-12{left:100%}.col-lg-push-11{left:91.66666667%}.col-lg-push-10{left:83.33333333%}.col-lg-push-9{left:75%}.col-lg-push-8{left:66.66666667%}.col-lg-push-7{left:58.33333333%}.col-lg-push-6{left:50%}.col-lg-push-5{left:41.66666667%}.col-lg-push-4{left:33.33333333%}.col-lg-push-3{left:25%}.col-lg-push-2{left:16.66666667%}.col-lg-push-1{left:8.33333333%}.col-lg-push-0{left:auto}.col-lg-offset-12{margin-left:100%}.col-lg-offset-11{margin-left:91.66666667%}.col-lg-offset-10{margin-left:83.33333333%}.col-lg-offset-9{margin-left:75%}.col-lg-offset-8{margin-left:66.66666667%}.col-lg-offset-7{margin-left:58.33333333%}.col-lg-offset-6{margin-left:50%}.col-lg-offset-5{margin-left:41.66666667%}.col-lg-offset-4{margin-left:33.33333333%}.col-lg-offset-3{margin-left:25%}.col-lg-offset-2{margin-left:16.66666667%}.col-lg-offset-1{margin-left:8.33333333%}.col-lg-offset-0{margin-left:0}}table{background-color:transparent}caption{padding-top:8px;padding-bottom:8px;color:#777;text-align:left}th{text-align:left}.table{width:100%;max-width:100%;margin-bottom:20px}.table>tbody>tr>td,.table>tbody>tr>th,.table>tfoot>tr>td,.table>tfoot>tr>th,.table>thead>tr>td,.table>thead>tr>th{padding:8px;line-height:1.42857143;vertical-align:top;border-top:1px solid #ddd}.table>thead>tr>th{vertical-align:bottom;border-bottom:2px solid #ddd}.table>caption+thead>tr:first-child>td,.table>caption+thead>tr:first-child>th,.table>colgroup+thead>tr:first-child>td,.table>colgroup+thead>tr:first-child>th,.table>thead:first-child>tr:first-child>td,.table>thead:first-child>tr:first-child>th{border-top:0}.table>tbody+tbody{border-top:2px solid #ddd}.table .table{background-color:#fff}.table-condensed>tbody>tr>td,.table-condensed>tbody>tr>th,.table-condensed>tfoot>tr>td,.table-condensed>tfoot>tr>th,.table-condensed>thead>tr>td,.table-condensed>thead>tr>th{padding:5px}.table-bordered{border:1px solid #ddd}.table-bordered>tbody>tr>td,.table-bordered>tbody>tr>th,.table-bordered>tfoot>tr>td,.table-bordered>tfoot>tr>th,.table-bordered>thead>tr>td,.table-bordered>thead>tr>th{border:1px solid #ddd}.table-bordered>thead>tr>td,.table-bordered>thead>tr>th{border-bottom-width:2px}.table-striped>tbody>tr:nth-of-type(odd){background-color:#f9f9f9}.table-hover>tbody>tr:hover{background-color:#f5f5f5}table col[class*=col-]{position:static;display:table-column;float:none}table td[class*=col-],table th[class*=col-]{position:static;display:table-cell;float:none}.table>tbody>tr.active>td,.table>tbody>tr.active>th,.table>tbody>tr>td.active,.table>tbody>tr>th.active,.table>tfoot>tr.active>td,.table>tfoot>tr.active>th,.table>tfoot>tr>td.active,.table>tfoot>tr>th.active,.table>thead>tr.active>td,.table>thead>tr.active>th,.table>thead>tr>td.active,.table>thead>tr>th.active{background-color:#f5f5f5}.table-hover>tbody>tr.active:hover>td,.table-hover>tbody>tr.active:hover>th,.table-hover>tbody>tr:hover>.active,.table-hover>tbody>tr>td.active:hover,.table-hover>tbody>tr>th.active:hover{background-color:#e8e8e8}.table>tbody>tr.success>td,.table>tbody>tr.success>th,.table>tbody>tr>td.success,.table>tbody>tr>th.success,.table>tfoot>tr.success>td,.table>tfoot>tr.success>th,.table>tfoot>tr>td.success,.table>tfoot>tr>th.success,.table>thead>tr.success>td,.table>thead>tr.success>th,.table>thead>tr>td.success,.table>thead>tr>th.success{background-color:#dff0d8}.table-hover>tbody>tr.success:hover>td,.table-hover>tbody>tr.success:hover>th,.table-hover>tbody>tr:hover>.success,.table-hover>tbody>tr>td.success:hover,.table-hover>tbody>tr>th.success:hover{background-color:#d0e9c6}.table>tbody>tr.info>td,.table>tbody>tr.info>th,.table>tbody>tr>td.info,.table>tbody>tr>th.info,.table>tfoot>tr.info>td,.table>tfoot>tr.info>th,.table>tfoot>tr>td.info,.table>tfoot>tr>th.info,.table>thead>tr.info>td,.table>thead>tr.info>th,.table>thead>tr>td.info,.table>thead>tr>th.info{background-color:#d9edf7}.table-hover>tbody>tr.info:hover>td,.table-hover>tbody>tr.info:hover>th,.table-hover>tbody>tr:hover>.info,.table-hover>tbody>tr>td.info:hover,.table-hover>tbody>tr>th.info:hover{background-color:#c4e3f3}.table>tbody>tr.warning>td,.table>tbody>tr.warning>th,.table>tbody>tr>td.warning,.table>tbody>tr>th.warning,.table>tfoot>tr.warning>td,.table>tfoot>tr.warning>th,.table>tfoot>tr>td.warning,.table>tfoot>tr>th.warning,.table>thead>tr.warning>td,.table>thead>tr.warning>th,.table>thead>tr>td.warning,.table>thead>tr>th.warning{background-color:#fcf8e3}.table-hover>tbody>tr.warning:hover>td,.table-hover>tbody>tr.warning:hover>th,.table-hover>tbody>tr:hover>.warning,.table-hover>tbody>tr>td.warning:hover,.table-hover>tbody>tr>th.warning:hover{background-color:#faf2cc}.table>tbody>tr.danger>td,.table>tbody>tr.danger>th,.table>tbody>tr>td.danger,.table>tbody>tr>th.danger,.table>tfoot>tr.danger>td,.table>tfoot>tr.danger>th,.table>tfoot>tr>td.danger,.table>tfoot>tr>th.danger,.table>thead>tr.danger>td,.table>thead>tr.danger>th,.table>thead>tr>td.danger,.table>thead>tr>th.danger{background-color:#f2dede}.table-hover>tbody>tr.danger:hover>td,.table-hover>tbody>tr.danger:hover>th,.table-hover>tbody>tr:hover>.danger,.table-hover>tbody>tr>td.danger:hover,.table-hover>tbody>tr>th.danger:hover{background-color:#ebcccc}.table-responsive{min-height:.01%;overflow-x:auto}@media screen and (max-width:767px){.table-responsive{width:100%;margin-bottom:15px;overflow-y:hidden;-ms-overflow-style:-ms-autohiding-scrollbar;border:1px solid #ddd}.table-responsive>.table{margin-bottom:0}.table-responsive>.table>tbody>tr>td,.table-responsive>.table>tbody>tr>th,.table-responsive>.table>tfoot>tr>td,.table-responsive>.table>tfoot>tr>th,.table-responsive>.table>thead>tr>td,.table-responsive>.table>thead>tr>th{white-space:nowrap}.table-responsive>.table-bordered{border:0}.table-responsive>.table-bordered>tbody>tr>td:first-child,.table-responsive>.table-bordered>tbody>tr>th:first-child,.table-responsive>.table-bordered>tfoot>tr>td:first-child,.table-responsive>.table-bordered>tfoot>tr>th:first-child,.table-responsive>.table-bordered>thead>tr>td:first-child,.table-responsive>.table-bordered>thead>tr>th:first-child{border-left:0}.table-responsive>.table-bordered>tbody>tr>td:last-child,.table-responsive>.table-bordered>tbody>tr>th:last-child,.table-responsive>.table-bordered>tfoot>tr>td:last-child,.table-responsive>.table-bordered>tfoot>tr>th:last-child,.table-responsive>.table-bordered>thead>tr>td:last-child,.table-responsive>.table-bordered>thead>tr>th:last-child{border-right:0}.table-responsive>.table-bordered>tbody>tr:last-child>td,.table-responsive>.table-bordered>tbody>tr:last-child>th,.table-responsive>.table-bordered>tfoot>tr:last-child>td,.table-responsive>.table-bordered>tfoot>tr:last-child>th{border-bottom:0}}fieldset{min-width:0;padding:0;margin:0;border:0}legend{display:block;width:100%;padding:0;margin-bottom:20px;font-size:21px;line-height:inherit;color:#333;border:0;border-bottom:1px solid #e5e5e5}label{display:inline-block;max-width:100%;margin-bottom:5px;font-weight:700}input[type=search]{-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}input[type=checkbox],input[type=radio]{margin:4px 0 0;margin-top:1px\9;line-height:normal}input[type=file]{display:block}input[type=range]{display:block;width:100%}select[multiple],select[size]{height:auto}input[type=file]:focus,input[type=checkbox]:focus,input[type=radio]:focus{outline:thin dotted;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}output{display:block;padding-top:7px;font-size:14px;line-height:1.42857143;color:#555}.form-control{display:block;width:100%;height:34px;padding:6px 12px;font-size:14px;line-height:1.42857143;color:#555;background-color:#fff;background-image:none;border:1px solid #ccc;border-radius:4px;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075);box-shadow:inset 0 1px 1px rgba(0,0,0,.075);-webkit-transition:border-color ease-in-out .15s,-webkit-box-shadow ease-in-out .15s;-o-transition:border-color ease-in-out .15s,box-shadow ease-in-out .15s;transition:border-color ease-in-out .15s,box-shadow ease-in-out .15s}.form-control:focus{border-color:#66afe9;outline:0;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 8px rgba(102,175,233,.6);box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 8px rgba(102,175,233,.6)}.form-control::-moz-placeholder{color:#999;opacity:1}.form-control:-ms-input-placeholder{color:#999}.form-control::-webkit-input-placeholder{color:#999}.form-control::-ms-expand{background-color:transparent;border:0}.form-control[disabled],.form-control[readonly],fieldset[disabled] .form-control{background-color:#eee;opacity:1}.form-control[disabled],fieldset[disabled] .form-control{cursor:not-allowed}textarea.form-control{height:auto}input[type=search]{-webkit-appearance:none}@media screen and (-webkit-min-device-pixel-ratio:0){input[type=date].form-control,input[type=time].form-control,input[type=datetime-local].form-control,input[type=month].form-control{line-height:34px}.input-group-sm input[type=date],.input-group-sm input[type=time],.input-group-sm input[type=datetime-local],.input-group-sm input[type=month],input[type=date].input-sm,input[type=time].input-sm,input[type=datetime-local].input-sm,input[type=month].input-sm{line-height:30px}.input-group-lg input[type=date],.input-group-lg input[type=time],.input-group-lg input[type=datetime-local],.input-group-lg input[type=month],input[type=date].input-lg,input[type=time].input-lg,input[type=datetime-local].input-lg,input[type=month].input-lg{line-height:46px}}.form-group{margin-bottom:15px}.checkbox,.radio{position:relative;display:block;margin-top:10px;margin-bottom:10px}.checkbox label,.radio label{min-height:20px;padding-left:20px;margin-bottom:0;font-weight:400;cursor:pointer}.checkbox input[type=checkbox],.checkbox-inline input[type=checkbox],.radio input[type=radio],.radio-inline input[type=radio]{position:absolute;margin-top:4px\9;margin-left:-20px}.checkbox+.checkbox,.radio+.radio{margin-top:-5px}.checkbox-inline,.radio-inline{position:relative;display:inline-block;padding-left:20px;margin-bottom:0;font-weight:400;vertical-align:middle;cursor:pointer}.checkbox-inline+.checkbox-inline,.radio-inline+.radio-inline{margin-top:0;margin-left:10px}fieldset[disabled] input[type=checkbox],fieldset[disabled] input[type=radio],input[type=checkbox].disabled,input[type=checkbox][disabled],input[type=radio].disabled,input[type=radio][disabled]{cursor:not-allowed}.checkbox-inline.disabled,.radio-inline.disabled,fieldset[disabled] .checkbox-inline,fieldset[disabled] .radio-inline{cursor:not-allowed}.checkbox.disabled label,.radio.disabled label,fieldset[disabled] .checkbox label,fieldset[disabled] .radio label{cursor:not-allowed}.form-control-static{min-height:34px;padding-top:7px;padding-bottom:7px;margin-bottom:0}.form-control-static.input-lg,.form-control-static.input-sm{padding-right:0;padding-left:0}.input-sm{height:30px;padding:5px 10px;font-size:12px;line-height:1.5;border-radius:3px}select.input-sm{height:30px;line-height:30px}select[multiple].input-sm,textarea.input-sm{height:auto}.form-group-sm .form-control{height:30px;padding:5px 10px;font-size:12px;line-height:1.5;border-radius:3px}.form-group-sm select.form-control{height:30px;line-height:30px}.form-group-sm select[multiple].form-control,.form-group-sm textarea.form-control{height:auto}.form-group-sm .form-control-static{height:30px;min-height:32px;padding:6px 10px;font-size:12px;line-height:1.5}.input-lg{height:46px;padding:10px 16px;font-size:18px;line-height:1.3333333;border-radius:6px}select.input-lg{height:46px;line-height:46px}select[multiple].input-lg,textarea.input-lg{height:auto}.form-group-lg .form-control{height:46px;padding:10px 16px;font-size:18px;line-height:1.3333333;border-radius:6px}.form-group-lg select.form-control{height:46px;line-height:46px}.form-group-lg select[multiple].form-control,.form-group-lg textarea.form-control{height:auto}.form-group-lg .form-control-static{height:46px;min-height:38px;padding:11px 16px;font-size:18px;line-height:1.3333333}.has-feedback{position:relative}.has-feedback .form-control{padding-right:42.5px}.form-control-feedback{position:absolute;top:0;right:0;z-index:2;display:block;width:34px;height:34px;line-height:34px;text-align:center;pointer-events:none}.form-group-lg .form-control+.form-control-feedback,.input-group-lg+.form-control-feedback,.input-lg+.form-control-feedback{width:46px;height:46px;line-height:46px}.form-group-sm .form-control+.form-control-feedback,.input-group-sm+.form-control-feedback,.input-sm+.form-control-feedback{width:30px;height:30px;line-height:30px}.has-success .checkbox,.has-success .checkbox-inline,.has-success .control-label,.has-success .help-block,.has-success .radio,.has-success .radio-inline,.has-success.checkbox label,.has-success.checkbox-inline label,.has-success.radio label,.has-success.radio-inline label{color:#3c763d}.has-success .form-control{border-color:#3c763d;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075);box-shadow:inset 0 1px 1px rgba(0,0,0,.075)}.has-success .form-control:focus{border-color:#2b542c;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #67b168;box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #67b168}.has-success .input-group-addon{color:#3c763d;background-color:#dff0d8;border-color:#3c763d}.has-success .form-control-feedback{color:#3c763d}.has-warning .checkbox,.has-warning .checkbox-inline,.has-warning .control-label,.has-warning .help-block,.has-warning .radio,.has-warning .radio-inline,.has-warning.checkbox label,.has-warning.checkbox-inline label,.has-warning.radio label,.has-warning.radio-inline label{color:#8a6d3b}.has-warning .form-control{border-color:#8a6d3b;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075);box-shadow:inset 0 1px 1px rgba(0,0,0,.075)}.has-warning .form-control:focus{border-color:#66512c;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #c0a16b;box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #c0a16b}.has-warning .input-group-addon{color:#8a6d3b;background-color:#fcf8e3;border-color:#8a6d3b}.has-warning .form-control-feedback{color:#8a6d3b}.has-error .checkbox,.has-error .checkbox-inline,.has-error .control-label,.has-error .help-block,.has-error .radio,.has-error .radio-inline,.has-error.checkbox label,.has-error.checkbox-inline label,.has-error.radio label,.has-error.radio-inline label{color:#a94442}.has-error .form-control{border-color:#a94442;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075);box-shadow:inset 0 1px 1px rgba(0,0,0,.075)}.has-error .form-control:focus{border-color:#843534;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #ce8483;box-shadow:inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #ce8483}.has-error .input-group-addon{color:#a94442;background-color:#f2dede;border-color:#a94442}.has-error .form-control-feedback{color:#a94442}.has-feedback label~.form-control-feedback{top:25px}.has-feedback label.sr-only~.form-control-feedback{top:0}.help-block{display:block;margin-top:5px;margin-bottom:10px;color:#737373}@media (min-width:768px){.form-inline .form-group{display:inline-block;margin-bottom:0;vertical-align:middle}.form-inline .form-control{display:inline-block;width:auto;vertical-align:middle}.form-inline .form-control-static{display:inline-block}.form-inline .input-group{display:inline-table;vertical-align:middle}.form-inline .input-group .form-control,.form-inline .input-group .input-group-addon,.form-inline .input-group .input-group-btn{width:auto}.form-inline .input-group>.form-control{width:100%}.form-inline .control-label{margin-bottom:0;vertical-align:middle}.form-inline .checkbox,.form-inline .radio{display:inline-block;margin-top:0;margin-bottom:0;vertical-align:middle}.form-inline .checkbox label,.form-inline .radio label{padding-left:0}.form-inline .checkbox input[type=checkbox],.form-inline .radio input[type=radio]{position:relative;margin-left:0}.form-inline .has-feedback .form-control-feedback{top:0}}.form-horizontal .checkbox,.form-horizontal .checkbox-inline,.form-horizontal .radio,.form-horizontal .radio-inline{padding-top:7px;margin-top:0;margin-bottom:0}.form-horizontal .checkbox,.form-horizontal .radio{min-height:27px}.form-horizontal .form-group{margin-right:-15px;margin-left:-15px}@media (min-width:768px){.form-horizontal .control-label{padding-top:7px;margin-bottom:0;text-align:right}}.form-horizontal .has-feedback .form-control-feedback{right:15px}@media (min-width:768px){.form-horizontal .form-group-lg .control-label{padding-top:11px;font-size:18px}}@media (min-width:768px){.form-horizontal .form-group-sm .control-label{padding-top:6px;font-size:12px}}.btn{display:inline-block;padding:6px 12px;margin-bottom:0;font-size:14px;font-weight:400;line-height:1.42857143;text-align:center;white-space:nowrap;vertical-align:middle;-ms-touch-action:manipulation;touch-action:manipulation;cursor:pointer;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;background-image:none;border:1px solid transparent;border-radius:4px}.btn.active.focus,.btn.active:focus,.btn.focus,.btn:active.focus,.btn:active:focus,.btn:focus{outline:thin dotted;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}.btn.focus,.btn:focus,.btn:hover{color:#333;text-decoration:none}.btn.active,.btn:active{background-image:none;outline:0;-webkit-box-shadow:inset 0 3px 5px rgba(0,0,0,.125);box-shadow:inset 0 3px 5px rgba(0,0,0,.125)}.btn.disabled,.btn[disabled],fieldset[disabled] .btn{cursor:not-allowed;filter:alpha(opacity=65);-webkit-box-shadow:none;box-shadow:none;opacity:.65}a.btn.disabled,fieldset[disabled] a.btn{pointer-events:none}.btn-default{color:#333;background-color:#fff;border-color:#ccc}.btn-default.focus,.btn-default:focus{color:#333;background-color:#e6e6e6;border-color:#8c8c8c}.btn-default:hover{color:#333;background-color:#e6e6e6;border-color:#adadad}.btn-default.active,.btn-default:active,.open>.dropdown-toggle.btn-default{color:#333;background-color:#e6e6e6;border-color:#adadad}.btn-default.active.focus,.btn-default.active:focus,.btn-default.active:hover,.btn-default:active.focus,.btn-default:active:focus,.btn-default:active:hover,.open>.dropdown-toggle.btn-default.focus,.open>.dropdown-toggle.btn-default:focus,.open>.dropdown-toggle.btn-default:hover{color:#333;background-color:#d4d4d4;border-color:#8c8c8c}.btn-default.active,.btn-default:active,.open>.dropdown-toggle.btn-default{background-image:none}.btn-default.disabled.focus,.btn-default.disabled:focus,.btn-default.disabled:hover,.btn-default[disabled].focus,.btn-default[disabled]:focus,.btn-default[disabled]:hover,fieldset[disabled] .btn-default.focus,fieldset[disabled] .btn-default:focus,fieldset[disabled] .btn-default:hover{background-color:#fff;border-color:#ccc}.btn-default .badge{color:#fff;background-color:#333}.btn-primary{color:#fff;background-color:#337ab7;border-color:#2e6da4}.btn-primary.focus,.btn-primary:focus{color:#fff;background-color:#286090;border-color:#122b40}.btn-primary:hover{color:#fff;background-color:#286090;border-color:#204d74}.btn-primary.active,.btn-primary:active,.open>.dropdown-toggle.btn-primary{color:#fff;background-color:#286090;border-color:#204d74}.btn-primary.active.focus,.btn-primary.active:focus,.btn-primary.active:hover,.btn-primary:active.focus,.btn-primary:active:focus,.btn-primary:active:hover,.open>.dropdown-toggle.btn-primary.focus,.open>.dropdown-toggle.btn-primary:focus,.open>.dropdown-toggle.btn-primary:hover{color:#fff;background-color:#204d74;border-color:#122b40}.btn-primary.active,.btn-primary:active,.open>.dropdown-toggle.btn-primary{background-image:none}.btn-primary.disabled.focus,.btn-primary.disabled:focus,.btn-primary.disabled:hover,.btn-primary[disabled].focus,.btn-primary[disabled]:focus,.btn-primary[disabled]:hover,fieldset[disabled] .btn-primary.focus,fieldset[disabled] .btn-primary:focus,fieldset[disabled] .btn-primary:hover{background-color:#337ab7;border-color:#2e6da4}.btn-primary .badge{color:#337ab7;background-color:#fff}.btn-success{color:#fff;background-color:#5cb85c;border-color:#4cae4c}.btn-success.focus,.btn-success:focus{color:#fff;background-color:#449d44;border-color:#255625}.btn-success:hover{color:#fff;background-color:#449d44;border-color:#398439}.btn-success.active,.btn-success:active,.open>.dropdown-toggle.btn-success{color:#fff;background-color:#449d44;border-color:#398439}.btn-success.active.focus,.btn-success.active:focus,.btn-success.active:hover,.btn-success:active.focus,.btn-success:active:focus,.btn-success:active:hover,.open>.dropdown-toggle.btn-success.focus,.open>.dropdown-toggle.btn-success:focus,.open>.dropdown-toggle.btn-success:hover{color:#fff;background-color:#398439;border-color:#255625}.btn-success.active,.btn-success:active,.open>.dropdown-toggle.btn-success{background-image:none}.btn-success.disabled.focus,.btn-success.disabled:focus,.btn-success.disabled:hover,.btn-success[disabled].focus,.btn-success[disabled]:focus,.btn-success[disabled]:hover,fieldset[disabled] .btn-success.focus,fieldset[disabled] .btn-success:focus,fieldset[disabled] .btn-success:hover{background-color:#5cb85c;border-color:#4cae4c}.btn-success .badge{color:#5cb85c;background-color:#fff}.btn-info{color:#fff;background-color:#5bc0de;border-color:#46b8da}.btn-info.focus,.btn-info:focus{color:#fff;background-color:#31b0d5;border-color:#1b6d85}.btn-info:hover{color:#fff;background-color:#31b0d5;border-color:#269abc}.btn-info.active,.btn-info:active,.open>.dropdown-toggle.btn-info{color:#fff;background-color:#31b0d5;border-color:#269abc}.btn-info.active.focus,.btn-info.active:focus,.btn-info.active:hover,.btn-info:active.focus,.btn-info:active:focus,.btn-info:active:hover,.open>.dropdown-toggle.btn-info.focus,.open>.dropdown-toggle.btn-info:focus,.open>.dropdown-toggle.btn-info:hover{color:#fff;background-color:#269abc;border-color:#1b6d85}.btn-info.active,.btn-info:active,.open>.dropdown-toggle.btn-info{background-image:none}.btn-info.disabled.focus,.btn-info.disabled:focus,.btn-info.disabled:hover,.btn-info[disabled].focus,.btn-info[disabled]:focus,.btn-info[disabled]:hover,fieldset[disabled] .btn-info.focus,fieldset[disabled] .btn-info:focus,fieldset[disabled] .btn-info:hover{background-color:#5bc0de;border-color:#46b8da}.btn-info .badge{color:#5bc0de;background-color:#fff}.btn-warning{color:#fff;background-color:#f0ad4e;border-color:#eea236}.btn-warning.focus,.btn-warning:focus{color:#fff;background-color:#ec971f;border-color:#985f0d}.btn-warning:hover{color:#fff;background-color:#ec971f;border-color:#d58512}.btn-warning.active,.btn-warning:active,.open>.dropdown-toggle.btn-warning{color:#fff;background-color:#ec971f;border-color:#d58512}.btn-warning.active.focus,.btn-warning.active:focus,.btn-warning.active:hover,.btn-warning:active.focus,.btn-warning:active:focus,.btn-warning:active:hover,.open>.dropdown-toggle.btn-warning.focus,.open>.dropdown-toggle.btn-warning:focus,.open>.dropdown-toggle.btn-warning:hover{color:#fff;background-color:#d58512;border-color:#985f0d}.btn-warning.active,.btn-warning:active,.open>.dropdown-toggle.btn-warning{background-image:none}.btn-warning.disabled.focus,.btn-warning.disabled:focus,.btn-warning.disabled:hover,.btn-warning[disabled].focus,.btn-warning[disabled]:focus,.btn-warning[disabled]:hover,fieldset[disabled] .btn-warning.focus,fieldset[disabled] .btn-warning:focus,fieldset[disabled] .btn-warning:hover{background-color:#f0ad4e;border-color:#eea236}.btn-warning .badge{color:#f0ad4e;background-color:#fff}.btn-danger{color:#fff;background-color:#d9534f;border-color:#d43f3a}.btn-danger.focus,.btn-danger:focus{color:#fff;background-color:#c9302c;border-color:#761c19}.btn-danger:hover{color:#fff;background-color:#c9302c;border-color:#ac2925}.btn-danger.active,.btn-danger:active,.open>.dropdown-toggle.btn-danger{color:#fff;background-color:#c9302c;border-color:#ac2925}.btn-danger.active.focus,.btn-danger.active:focus,.btn-danger.active:hover,.btn-danger:active.focus,.btn-danger:active:focus,.btn-danger:active:hover,.open>.dropdown-toggle.btn-danger.focus,.open>.dropdown-toggle.btn-danger:focus,.open>.dropdown-toggle.btn-danger:hover{color:#fff;background-color:#ac2925;border-color:#761c19}.btn-danger.active,.btn-danger:active,.open>.dropdown-toggle.btn-danger{background-image:none}.btn-danger.disabled.focus,.btn-danger.disabled:focus,.btn-danger.disabled:hover,.btn-danger[disabled].focus,.btn-danger[disabled]:focus,.btn-danger[disabled]:hover,fieldset[disabled] .btn-danger.focus,fieldset[disabled] .btn-danger:focus,fieldset[disabled] .btn-danger:hover{background-color:#d9534f;border-color:#d43f3a}.btn-danger .badge{color:#d9534f;background-color:#fff}.btn-link{font-weight:400;color:#337ab7;border-radius:0}.btn-link,.btn-link.active,.btn-link:active,.btn-link[disabled],fieldset[disabled] .btn-link{background-color:transparent;-webkit-box-shadow:none;box-shadow:none}.btn-link,.btn-link:active,.btn-link:focus,.btn-link:hover{border-color:transparent}.btn-link:focus,.btn-link:hover{color:#23527c;text-decoration:underline;background-color:transparent}.btn-link[disabled]:focus,.btn-link[disabled]:hover,fieldset[disabled] .btn-link:focus,fieldset[disabled] .btn-link:hover{color:#777;text-decoration:none}.btn-group-lg>.btn,.btn-lg{padding:10px 16px;font-size:18px;line-height:1.3333333;border-radius:6px}.btn-group-sm>.btn,.btn-sm{padding:5px 10px;font-size:12px;line-height:1.5;border-radius:3px}.btn-group-xs>.btn,.btn-xs{padding:1px 5px;font-size:12px;line-height:1.5;border-radius:3px}.btn-block{display:block;width:100%}.btn-block+.btn-block{margin-top:5px}input[type=button].btn-block,input[type=reset].btn-block,input[type=submit].btn-block{width:100%}.fade{opacity:0;-webkit-transition:opacity .15s linear;-o-transition:opacity .15s linear;transition:opacity .15s linear}.fade.in{opacity:1}.collapse{display:none}.collapse.in{display:block}tr.collapse.in{display:table-row}tbody.collapse.in{display:table-row-group}.collapsing{position:relative;height:0;overflow:hidden;-webkit-transition-timing-function:ease;-o-transition-timing-function:ease;transition-timing-function:ease;-webkit-transition-duration:.35s;-o-transition-duration:.35s;transition-duration:.35s;-webkit-transition-property:height,visibility;-o-transition-property:height,visibility;transition-property:height,visibility}.caret{display:inline-block;width:0;height:0;margin-left:2px;vertical-align:middle;border-top:4px dashed;border-top:4px solid\9;border-right:4px solid transparent;border-left:4px solid transparent}.dropdown,.dropup{position:relative}.dropdown-toggle:focus{outline:0}.dropdown-menu{position:absolute;top:100%;left:0;z-index:1000;display:none;float:left;min-width:160px;padding:5px 0;margin:2px 0 0;font-size:14px;text-align:left;list-style:none;background-color:#fff;-webkit-background-clip:padding-box;background-clip:padding-box;border:1px solid #ccc;border:1px solid rgba(0,0,0,.15);border-radius:4px;-webkit-box-shadow:0 6px 12px rgba(0,0,0,.175);box-shadow:0 6px 12px rgba(0,0,0,.175)}.dropdown-menu.pull-right{right:0;left:auto}.dropdown-menu .divider{height:1px;margin:9px 0;overflow:hidden;background-color:#e5e5e5}.dropdown-menu>li>a{display:block;padding:3px 20px;clear:both;font-weight:400;line-height:1.42857143;color:#333;white-space:nowrap}.dropdown-menu>li>a:focus,.dropdown-menu>li>a:hover{color:#262626;text-decoration:none;background-color:#f5f5f5}.dropdown-menu>.active>a,.dropdown-menu>.active>a:focus,.dropdown-menu>.active>a:hover{color:#fff;text-decoration:none;background-color:#337ab7;outline:0}.dropdown-menu>.disabled>a,.dropdown-menu>.disabled>a:focus,.dropdown-menu>.disabled>a:hover{color:#777}.dropdown-menu>.disabled>a:focus,.dropdown-menu>.disabled>a:hover{text-decoration:none;cursor:not-allowed;background-color:transparent;background-image:none;filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.open>.dropdown-menu{display:block}.open>a{outline:0}.dropdown-menu-right{right:0;left:auto}.dropdown-menu-left{right:auto;left:0}.dropdown-header{display:block;padding:3px 20px;font-size:12px;line-height:1.42857143;color:#777;white-space:nowrap}.dropdown-backdrop{position:fixed;top:0;right:0;bottom:0;left:0;z-index:990}.pull-right>.dropdown-menu{right:0;left:auto}.dropup .caret,.navbar-fixed-bottom .dropdown .caret{content:"";border-top:0;border-bottom:4px dashed;border-bottom:4px solid\9}.dropup .dropdown-menu,.navbar-fixed-bottom .dropdown .dropdown-menu{top:auto;bottom:100%;margin-bottom:2px}@media (min-width:768px){.navbar-right .dropdown-menu{right:0;left:auto}.navbar-right .dropdown-menu-left{right:auto;left:0}}.btn-group,.btn-group-vertical{position:relative;display:inline-block;vertical-align:middle}.btn-group-vertical>.btn,.btn-group>.btn{position:relative;float:left}.btn-group-vertical>.btn.active,.btn-group-vertical>.btn:active,.btn-group-vertical>.btn:focus,.btn-group-vertical>.btn:hover,.btn-group>.btn.active,.btn-group>.btn:active,.btn-group>.btn:focus,.btn-group>.btn:hover{z-index:2}.btn-group .btn+.btn,.btn-group .btn+.btn-group,.btn-group .btn-group+.btn,.btn-group .btn-group+.btn-group{margin-left:-1px}.btn-toolbar{margin-left:-5px}.btn-toolbar .btn,.btn-toolbar .btn-group,.btn-toolbar .input-group{float:left}.btn-toolbar>.btn,.btn-toolbar>.btn-group,.btn-toolbar>.input-group{margin-left:5px}.btn-group>.btn:not(:first-child):not(:last-child):not(.dropdown-toggle){border-radius:0}.btn-group>.btn:first-child{margin-left:0}.btn-group>.btn:first-child:not(:last-child):not(.dropdown-toggle){border-top-right-radius:0;border-bottom-right-radius:0}.btn-group>.btn:last-child:not(:first-child),.btn-group>.dropdown-toggle:not(:first-child){border-top-left-radius:0;border-bottom-left-radius:0}.btn-group>.btn-group{float:left}.btn-group>.btn-group:not(:first-child):not(:last-child)>.btn{border-radius:0}.btn-group>.btn-group:first-child:not(:last-child)>.btn:last-child,.btn-group>.btn-group:first-child:not(:last-child)>.dropdown-toggle{border-top-right-radius:0;border-bottom-right-radius:0}.btn-group>.btn-group:last-child:not(:first-child)>.btn:first-child{border-top-left-radius:0;border-bottom-left-radius:0}.btn-group .dropdown-toggle:active,.btn-group.open .dropdown-toggle{outline:0}.btn-group>.btn+.dropdown-toggle{padding-right:8px;padding-left:8px}.btn-group>.btn-lg+.dropdown-toggle{padding-right:12px;padding-left:12px}.btn-group.open .dropdown-toggle{-webkit-box-shadow:inset 0 3px 5px rgba(0,0,0,.125);box-shadow:inset 0 3px 5px rgba(0,0,0,.125)}.btn-group.open .dropdown-toggle.btn-link{-webkit-box-shadow:none;box-shadow:none}.btn .caret{margin-left:0}.btn-lg .caret{border-width:5px 5px 0;border-bottom-width:0}.dropup .btn-lg .caret{border-width:0 5px 5px}.btn-group-vertical>.btn,.btn-group-vertical>.btn-group,.btn-group-vertical>.btn-group>.btn{display:block;float:none;width:100%;max-width:100%}.btn-group-vertical>.btn-group>.btn{float:none}.btn-group-vertical>.btn+.btn,.btn-group-vertical>.btn+.btn-group,.btn-group-vertical>.btn-group+.btn,.btn-group-vertical>.btn-group+.btn-group{margin-top:-1px;margin-left:0}.btn-group-vertical>.btn:not(:first-child):not(:last-child){border-radius:0}.btn-group-vertical>.btn:first-child:not(:last-child){border-top-left-radius:4px;border-top-right-radius:4px;border-bottom-right-radius:0;border-bottom-left-radius:0}.btn-group-vertical>.btn:last-child:not(:first-child){border-top-left-radius:0;border-top-right-radius:0;border-bottom-right-radius:4px;border-bottom-left-radius:4px}.btn-group-vertical>.btn-group:not(:first-child):not(:last-child)>.btn{border-radius:0}.btn-group-vertical>.btn-group:first-child:not(:last-child)>.btn:last-child,.btn-group-vertical>.btn-group:first-child:not(:last-child)>.dropdown-toggle{border-bottom-right-radius:0;border-bottom-left-radius:0}.btn-group-vertical>.btn-group:last-child:not(:first-child)>.btn:first-child{border-top-left-radius:0;border-top-right-radius:0}.btn-group-justified{display:table;width:100%;table-layout:fixed;border-collapse:separate}.btn-group-justified>.btn,.btn-group-justified>.btn-group{display:table-cell;float:none;width:1%}.btn-group-justified>.btn-group .btn{width:100%}.btn-group-justified>.btn-group .dropdown-menu{left:auto}[data-toggle=buttons]>.btn input[type=checkbox],[data-toggle=buttons]>.btn input[type=radio],[data-toggle=buttons]>.btn-group>.btn input[type=checkbox],[data-toggle=buttons]>.btn-group>.btn input[type=radio]{position:absolute;clip:rect(0,0,0,0);pointer-events:none}.input-group{position:relative;display:table;border-collapse:separate}.input-group[class*=col-]{float:none;padding-right:0;padding-left:0}.input-group .form-control{position:relative;z-index:2;float:left;width:100%;margin-bottom:0}.input-group .form-control:focus{z-index:3}.input-group-lg>.form-control,.input-group-lg>.input-group-addon,.input-group-lg>.input-group-btn>.btn{height:46px;padding:10px 16px;font-size:18px;line-height:1.3333333;border-radius:6px}select.input-group-lg>.form-control,select.input-group-lg>.input-group-addon,select.input-group-lg>.input-group-btn>.btn{height:46px;line-height:46px}select[multiple].input-group-lg>.form-control,select[multiple].input-group-lg>.input-group-addon,select[multiple].input-group-lg>.input-group-btn>.btn,textarea.input-group-lg>.form-control,textarea.input-group-lg>.input-group-addon,textarea.input-group-lg>.input-group-btn>.btn{height:auto}.input-group-sm>.form-control,.input-group-sm>.input-group-addon,.input-group-sm>.input-group-btn>.btn{height:30px;padding:5px 10px;font-size:12px;line-height:1.5;border-radius:3px}select.input-group-sm>.form-control,select.input-group-sm>.input-group-addon,select.input-group-sm>.input-group-btn>.btn{height:30px;line-height:30px}select[multiple].input-group-sm>.form-control,select[multiple].input-group-sm>.input-group-addon,select[multiple].input-group-sm>.input-group-btn>.btn,textarea.input-group-sm>.form-control,textarea.input-group-sm>.input-group-addon,textarea.input-group-sm>.input-group-btn>.btn{height:auto}.input-group .form-control,.input-group-addon,.input-group-btn{display:table-cell}.input-group .form-control:not(:first-child):not(:last-child),.input-group-addon:not(:first-child):not(:last-child),.input-group-btn:not(:first-child):not(:last-child){border-radius:0}.input-group-addon,.input-group-btn{width:1%;white-space:nowrap;vertical-align:middle}.input-group-addon{padding:6px 12px;font-size:14px;font-weight:400;line-height:1;color:#555;text-align:center;background-color:#eee;border:1px solid #ccc;border-radius:4px}.input-group-addon.input-sm{padding:5px 10px;font-size:12px;border-radius:3px}.input-group-addon.input-lg{padding:10px 16px;font-size:18px;border-radius:6px}.input-group-addon input[type=checkbox],.input-group-addon input[type=radio]{margin-top:0}.input-group .form-control:first-child,.input-group-addon:first-child,.input-group-btn:first-child>.btn,.input-group-btn:first-child>.btn-group>.btn,.input-group-btn:first-child>.dropdown-toggle,.input-group-btn:last-child>.btn-group:not(:last-child)>.btn,.input-group-btn:last-child>.btn:not(:last-child):not(.dropdown-toggle){border-top-right-radius:0;border-bottom-right-radius:0}.input-group-addon:first-child{border-right:0}.input-group .form-control:last-child,.input-group-addon:last-child,.input-group-btn:first-child>.btn-group:not(:first-child)>.btn,.input-group-btn:first-child>.btn:not(:first-child),.input-group-btn:last-child>.btn,.input-group-btn:last-child>.btn-group>.btn,.input-group-btn:last-child>.dropdown-toggle{border-top-left-radius:0;border-bottom-left-radius:0}.input-group-addon:last-child{border-left:0}.input-group-btn{position:relative;font-size:0;white-space:nowrap}.input-group-btn>.btn{position:relative}.input-group-btn>.btn+.btn{margin-left:-1px}.input-group-btn>.btn:active,.input-group-btn>.btn:focus,.input-group-btn>.btn:hover{z-index:2}.input-group-btn:first-child>.btn,.input-group-btn:first-child>.btn-group{margin-right:-1px}.input-group-btn:last-child>.btn,.input-group-btn:last-child>.btn-group{z-index:2;margin-left:-1px}.nav{padding-left:0;margin-bottom:0;list-style:none}.nav>li{position:relative;display:block}.nav>li>a{position:relative;display:block;padding:10px 15px}.nav>li>a:focus,.nav>li>a:hover{text-decoration:none;background-color:#eee}.nav>li.disabled>a{color:#777}.nav>li.disabled>a:focus,.nav>li.disabled>a:hover{color:#777;text-decoration:none;cursor:not-allowed;background-color:transparent}.nav .open>a,.nav .open>a:focus,.nav .open>a:hover{background-color:#eee;border-color:#337ab7}.nav .nav-divider{height:1px;margin:9px 0;overflow:hidden;background-color:#e5e5e5}.nav>li>a>img{max-width:none}.nav-tabs{border-bottom:1px solid #ddd}.nav-tabs>li{float:left;margin-bottom:-1px}.nav-tabs>li>a{margin-right:2px;line-height:1.42857143;border:1px solid transparent;border-radius:4px 4px 0 0}.nav-tabs>li>a:hover{border-color:#eee #eee #ddd}.nav-tabs>li.active>a,.nav-tabs>li.active>a:focus,.nav-tabs>li.active>a:hover{color:#555;cursor:default;background-color:#fff;border:1px solid #ddd;border-bottom-color:transparent}.nav-tabs.nav-justified{width:100%;border-bottom:0}.nav-tabs.nav-justified>li{float:none}.nav-tabs.nav-justified>li>a{margin-bottom:5px;text-align:center}.nav-tabs.nav-justified>.dropdown .dropdown-menu{top:auto;left:auto}@media (min-width:768px){.nav-tabs.nav-justified>li{display:table-cell;width:1%}.nav-tabs.nav-justified>li>a{margin-bottom:0}}.nav-tabs.nav-justified>li>a{margin-right:0;border-radius:4px}.nav-tabs.nav-justified>.active>a,.nav-tabs.nav-justified>.active>a:focus,.nav-tabs.nav-justified>.active>a:hover{border:1px solid #ddd}@media (min-width:768px){.nav-tabs.nav-justified>li>a{border-bottom:1px solid #ddd;border-radius:4px 4px 0 0}.nav-tabs.nav-justified>.active>a,.nav-tabs.nav-justified>.active>a:focus,.nav-tabs.nav-justified>.active>a:hover{border-bottom-color:#fff}}.nav-pills>li{float:left}.nav-pills>li>a{border-radius:4px}.nav-pills>li+li{margin-left:2px}.nav-pills>li.active>a,.nav-pills>li.active>a:focus,.nav-pills>li.active>a:hover{color:#fff;background-color:#337ab7}.nav-stacked>li{float:none}.nav-stacked>li+li{margin-top:2px;margin-left:0}.nav-justified{width:100%}.nav-justified>li{float:none}.nav-justified>li>a{margin-bottom:5px;text-align:center}.nav-justified>.dropdown .dropdown-menu{top:auto;left:auto}@media (min-width:768px){.nav-justified>li{display:table-cell;width:1%}.nav-justified>li>a{margin-bottom:0}}.nav-tabs-justified{border-bottom:0}.nav-tabs-justified>li>a{margin-right:0;border-radius:4px}.nav-tabs-justified>.active>a,.nav-tabs-justified>.active>a:focus,.nav-tabs-justified>.active>a:hover{border:1px solid #ddd}@media (min-width:768px){.nav-tabs-justified>li>a{border-bottom:1px solid #ddd;border-radius:4px 4px 0 0}.nav-tabs-justified>.active>a,.nav-tabs-justified>.active>a:focus,.nav-tabs-justified>.active>a:hover{border-bottom-color:#fff}}.tab-content>.tab-pane{display:none}.tab-content>.active{display:block}.nav-tabs .dropdown-menu{margin-top:-1px;border-top-left-radius:0;border-top-right-radius:0}.navbar{position:relative;min-height:50px;margin-bottom:20px;border:1px solid transparent}@media (min-width:768px){.navbar{border-radius:4px}}@media (min-width:768px){.navbar-header{float:left}}.navbar-collapse{padding-right:15px;padding-left:15px;overflow-x:visible;-webkit-overflow-scrolling:touch;border-top:1px solid transparent;-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,.1);box-shadow:inset 0 1px 0 rgba(255,255,255,.1)}.navbar-collapse.in{overflow-y:auto}@media (min-width:768px){.navbar-collapse{width:auto;border-top:0;-webkit-box-shadow:none;box-shadow:none}.navbar-collapse.collapse{display:block!important;height:auto!important;padding-bottom:0;overflow:visible!important}.navbar-collapse.in{overflow-y:visible}.navbar-fixed-bottom .navbar-collapse,.navbar-fixed-top .navbar-collapse,.navbar-static-top .navbar-collapse{padding-right:0;padding-left:0}}.navbar-fixed-bottom .navbar-collapse,.navbar-fixed-top .navbar-collapse{max-height:340px}@media (max-device-width:480px) and (orientation:landscape){.navbar-fixed-bottom .navbar-collapse,.navbar-fixed-top .navbar-collapse{max-height:200px}}.container-fluid>.navbar-collapse,.container-fluid>.navbar-header,.container>.navbar-collapse,.container>.navbar-header{margin-right:-15px;margin-left:-15px}@media (min-width:768px){.container-fluid>.navbar-collapse,.container-fluid>.navbar-header,.container>.navbar-collapse,.container>.navbar-header{margin-right:0;margin-left:0}}.navbar-static-top{z-index:1000;border-width:0 0 1px}@media (min-width:768px){.navbar-static-top{border-radius:0}}.navbar-fixed-bottom,.navbar-fixed-top{position:fixed;right:0;left:0;z-index:1030}@media (min-width:768px){.navbar-fixed-bottom,.navbar-fixed-top{border-radius:0}}.navbar-fixed-top{top:0;border-width:0 0 1px}.navbar-fixed-bottom{bottom:0;margin-bottom:0;border-width:1px 0 0}.navbar-brand{float:left;height:50px;padding:15px 15px;font-size:18px;line-height:20px}.navbar-brand:focus,.navbar-brand:hover{text-decoration:none}.navbar-brand>img{display:block}@media (min-width:768px){.navbar>.container .navbar-brand,.navbar>.container-fluid .navbar-brand{margin-left:-15px}}.navbar-toggle{position:relative;float:right;padding:9px 10px;margin-top:8px;margin-right:15px;margin-bottom:8px;background-color:transparent;background-image:none;border:1px solid transparent;border-radius:4px}.navbar-toggle:focus{outline:0}.navbar-toggle .icon-bar{display:block;width:22px;height:2px;border-radius:1px}.navbar-toggle .icon-bar+.icon-bar{margin-top:4px}@media (min-width:768px){.navbar-toggle{display:none}}.navbar-nav{margin:7.5px -15px}.navbar-nav>li>a{padding-top:10px;padding-bottom:10px;line-height:20px}@media (max-width:767px){.navbar-nav .open .dropdown-menu{position:static;float:none;width:auto;margin-top:0;background-color:transparent;border:0;-webkit-box-shadow:none;box-shadow:none}.navbar-nav .open .dropdown-menu .dropdown-header,.navbar-nav .open .dropdown-menu>li>a{padding:5px 15px 5px 25px}.navbar-nav .open .dropdown-menu>li>a{line-height:20px}.navbar-nav .open .dropdown-menu>li>a:focus,.navbar-nav .open .dropdown-menu>li>a:hover{background-image:none}}@media (min-width:768px){.navbar-nav{float:left;margin:0}.navbar-nav>li{float:left}.navbar-nav>li>a{padding-top:15px;padding-bottom:15px}}.navbar-form{padding:10px 15px;margin-top:8px;margin-right:-15px;margin-bottom:8px;margin-left:-15px;border-top:1px solid transparent;border-bottom:1px solid transparent;-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,.1),0 1px 0 rgba(255,255,255,.1);box-shadow:inset 0 1px 0 rgba(255,255,255,.1),0 1px 0 rgba(255,255,255,.1)}@media (min-width:768px){.navbar-form .form-group{display:inline-block;margin-bottom:0;vertical-align:middle}.navbar-form .form-control{display:inline-block;width:auto;vertical-align:middle}.navbar-form .form-control-static{display:inline-block}.navbar-form .input-group{display:inline-table;vertical-align:middle}.navbar-form .input-group .form-control,.navbar-form .input-group .input-group-addon,.navbar-form .input-group .input-group-btn{width:auto}.navbar-form .input-group>.form-control{width:100%}.navbar-form .control-label{margin-bottom:0;vertical-align:middle}.navbar-form .checkbox,.navbar-form .radio{display:inline-block;margin-top:0;margin-bottom:0;vertical-align:middle}.navbar-form .checkbox label,.navbar-form .radio label{padding-left:0}.navbar-form .checkbox input[type=checkbox],.navbar-form .radio input[type=radio]{position:relative;margin-left:0}.navbar-form .has-feedback .form-control-feedback{top:0}}@media (max-width:767px){.navbar-form .form-group{margin-bottom:5px}.navbar-form .form-group:last-child{margin-bottom:0}}@media (min-width:768px){.navbar-form{width:auto;padding-top:0;padding-bottom:0;margin-right:0;margin-left:0;border:0;-webkit-box-shadow:none;box-shadow:none}}.navbar-nav>li>.dropdown-menu{margin-top:0;border-top-left-radius:0;border-top-right-radius:0}.navbar-fixed-bottom .navbar-nav>li>.dropdown-menu{margin-bottom:0;border-top-left-radius:4px;border-top-right-radius:4px;border-bottom-right-radius:0;border-bottom-left-radius:0}.navbar-btn{margin-top:8px;margin-bottom:8px}.navbar-btn.btn-sm{margin-top:10px;margin-bottom:10px}.navbar-btn.btn-xs{margin-top:14px;margin-bottom:14px}.navbar-text{margin-top:15px;margin-bottom:15px}@media (min-width:768px){.navbar-text{float:left;margin-right:15px;margin-left:15px}}@media (min-width:768px){.navbar-left{float:left!important}.navbar-right{float:right!important;margin-right:-15px}.navbar-right~.navbar-right{margin-right:0}}.navbar-default{background-color:#f8f8f8;border-color:#e7e7e7}.navbar-default .navbar-brand{color:#777}.navbar-default .navbar-brand:focus,.navbar-default .navbar-brand:hover{color:#5e5e5e;background-color:transparent}.navbar-default .navbar-text{color:#777}.navbar-default .navbar-nav>li>a{color:#777}.navbar-default .navbar-nav>li>a:focus,.navbar-default .navbar-nav>li>a:hover{color:#333;background-color:transparent}.navbar-default .navbar-nav>.active>a,.navbar-default .navbar-nav>.active>a:focus,.navbar-default .navbar-nav>.active>a:hover{color:#555;background-color:#e7e7e7}.navbar-default .navbar-nav>.disabled>a,.navbar-default .navbar-nav>.disabled>a:focus,.navbar-default .navbar-nav>.disabled>a:hover{color:#ccc;background-color:transparent}.navbar-default .navbar-toggle{border-color:#ddd}.navbar-default .navbar-toggle:focus,.navbar-default .navbar-toggle:hover{background-color:#ddd}.navbar-default .navbar-toggle .icon-bar{background-color:#888}.navbar-default .navbar-collapse,.navbar-default .navbar-form{border-color:#e7e7e7}.navbar-default .navbar-nav>.open>a,.navbar-default .navbar-nav>.open>a:focus,.navbar-default .navbar-nav>.open>a:hover{color:#555;background-color:#e7e7e7}@media (max-width:767px){.navbar-default .navbar-nav .open .dropdown-menu>li>a{color:#777}.navbar-default .navbar-nav .open .dropdown-menu>li>a:focus,.navbar-default .navbar-nav .open .dropdown-menu>li>a:hover{color:#333;background-color:transparent}.navbar-default .navbar-nav .open .dropdown-menu>.active>a,.navbar-default .navbar-nav .open .dropdown-menu>.active>a:focus,.navbar-default .navbar-nav .open .dropdown-menu>.active>a:hover{color:#555;background-color:#e7e7e7}.navbar-default .navbar-nav .open .dropdown-menu>.disabled>a,.navbar-default .navbar-nav .open .dropdown-menu>.disabled>a:focus,.navbar-default .navbar-nav .open .dropdown-menu>.disabled>a:hover{color:#ccc;background-color:transparent}}.navbar-default .navbar-link{color:#777}.navbar-default .navbar-link:hover{color:#333}.navbar-default .btn-link{color:#777}.navbar-default .btn-link:focus,.navbar-default .btn-link:hover{color:#333}.navbar-default .btn-link[disabled]:focus,.navbar-default .btn-link[disabled]:hover,fieldset[disabled] .navbar-default .btn-link:focus,fieldset[disabled] .navbar-default .btn-link:hover{color:#ccc}.navbar-inverse{background-color:#222;border-color:#080808}.navbar-inverse .navbar-brand{color:#9d9d9d}.navbar-inverse .navbar-brand:focus,.navbar-inverse .navbar-brand:hover{color:#fff;background-color:transparent}.navbar-inverse .navbar-text{color:#9d9d9d}.navbar-inverse .navbar-nav>li>a{color:#9d9d9d}.navbar-inverse .navbar-nav>li>a:focus,.navbar-inverse .navbar-nav>li>a:hover{color:#fff;background-color:transparent}.navbar-inverse .navbar-nav>.active>a,.navbar-inverse .navbar-nav>.active>a:focus,.navbar-inverse .navbar-nav>.active>a:hover{color:#fff;background-color:#080808}.navbar-inverse .navbar-nav>.disabled>a,.navbar-inverse .navbar-nav>.disabled>a:focus,.navbar-inverse .navbar-nav>.disabled>a:hover{color:#444;background-color:transparent}.navbar-inverse .navbar-toggle{border-color:#333}.navbar-inverse .navbar-toggle:focus,.navbar-inverse .navbar-toggle:hover{background-color:#333}.navbar-inverse .navbar-toggle .icon-bar{background-color:#fff}.navbar-inverse .navbar-collapse,.navbar-inverse .navbar-form{border-color:#101010}.navbar-inverse .navbar-nav>.open>a,.navbar-inverse .navbar-nav>.open>a:focus,.navbar-inverse .navbar-nav>.open>a:hover{color:#fff;background-color:#080808}@media (max-width:767px){.navbar-inverse .navbar-nav .open .dropdown-menu>.dropdown-header{border-color:#080808}.navbar-inverse .navbar-nav .open .dropdown-menu .divider{background-color:#080808}.navbar-inverse .navbar-nav .open .dropdown-menu>li>a{color:#9d9d9d}.navbar-inverse .navbar-nav .open .dropdown-menu>li>a:focus,.navbar-inverse .navbar-nav .open .dropdown-menu>li>a:hover{color:#fff;background-color:transparent}.navbar-inverse .navbar-nav .open .dropdown-menu>.active>a,.navbar-inverse .navbar-nav .open .dropdown-menu>.active>a:focus,.navbar-inverse .navbar-nav .open .dropdown-menu>.active>a:hover{color:#fff;background-color:#080808}.navbar-inverse .navbar-nav .open .dropdown-menu>.disabled>a,.navbar-inverse .navbar-nav .open .dropdown-menu>.disabled>a:focus,.navbar-inverse .navbar-nav .open .dropdown-menu>.disabled>a:hover{color:#444;background-color:transparent}}.navbar-inverse .navbar-link{color:#9d9d9d}.navbar-inverse .navbar-link:hover{color:#fff}.navbar-inverse .btn-link{color:#9d9d9d}.navbar-inverse .btn-link:focus,.navbar-inverse .btn-link:hover{color:#fff}.navbar-inverse .btn-link[disabled]:focus,.navbar-inverse .btn-link[disabled]:hover,fieldset[disabled] .navbar-inverse .btn-link:focus,fieldset[disabled] .navbar-inverse .btn-link:hover{color:#444}.breadcrumb{padding:8px 15px;margin-bottom:20px;list-style:none;background-color:#f5f5f5;border-radius:4px}.breadcrumb>li{display:inline-block}.breadcrumb>li+li:before{padding:0 5px;color:#ccc;content:"/\00a0"}.breadcrumb>.active{color:#777}.pagination{display:inline-block;padding-left:0;margin:20px 0;border-radius:4px}.pagination>li{display:inline}.pagination>li>a,.pagination>li>span{position:relative;float:left;padding:6px 12px;margin-left:-1px;line-height:1.42857143;color:#337ab7;text-decoration:none;background-color:#fff;border:1px solid #ddd}.pagination>li:first-child>a,.pagination>li:first-child>span{margin-left:0;border-top-left-radius:4px;border-bottom-left-radius:4px}.pagination>li:last-child>a,.pagination>li:last-child>span{border-top-right-radius:4px;border-bottom-right-radius:4px}.pagination>li>a:focus,.pagination>li>a:hover,.pagination>li>span:focus,.pagination>li>span:hover{z-index:2;color:#23527c;background-color:#eee;border-color:#ddd}.pagination>.active>a,.pagination>.active>a:focus,.pagination>.active>a:hover,.pagination>.active>span,.pagination>.active>span:focus,.pagination>.active>span:hover{z-index:3;color:#fff;cursor:default;background-color:#337ab7;border-color:#337ab7}.pagination>.disabled>a,.pagination>.disabled>a:focus,.pagination>.disabled>a:hover,.pagination>.disabled>span,.pagination>.disabled>span:focus,.pagination>.disabled>span:hover{color:#777;cursor:not-allowed;background-color:#fff;border-color:#ddd}.pagination-lg>li>a,.pagination-lg>li>span{padding:10px 16px;font-size:18px;line-height:1.3333333}.pagination-lg>li:first-child>a,.pagination-lg>li:first-child>span{border-top-left-radius:6px;border-bottom-left-radius:6px}.pagination-lg>li:last-child>a,.pagination-lg>li:last-child>span{border-top-right-radius:6px;border-bottom-right-radius:6px}.pagination-sm>li>a,.pagination-sm>li>span{padding:5px 10px;font-size:12px;line-height:1.5}.pagination-sm>li:first-child>a,.pagination-sm>li:first-child>span{border-top-left-radius:3px;border-bottom-left-radius:3px}.pagination-sm>li:last-child>a,.pagination-sm>li:last-child>span{border-top-right-radius:3px;border-bottom-right-radius:3px}.pager{padding-left:0;margin:20px 0;text-align:center;list-style:none}.pager li{display:inline}.pager li>a,.pager li>span{display:inline-block;padding:5px 14px;background-color:#fff;border:1px solid #ddd;border-radius:15px}.pager li>a:focus,.pager li>a:hover{text-decoration:none;background-color:#eee}.pager .next>a,.pager .next>span{float:right}.pager .previous>a,.pager .previous>span{float:left}.pager .disabled>a,.pager .disabled>a:focus,.pager .disabled>a:hover,.pager .disabled>span{color:#777;cursor:not-allowed;background-color:#fff}.label{display:inline;padding:.2em .6em .3em;font-size:75%;font-weight:700;line-height:1;color:#fff;text-align:center;white-space:nowrap;vertical-align:baseline;border-radius:.25em}a.label:focus,a.label:hover{color:#fff;text-decoration:none;cursor:pointer}.label:empty{display:none}.btn .label{position:relative;top:-1px}.label-default{background-color:#777}.label-default[href]:focus,.label-default[href]:hover{background-color:#5e5e5e}.label-primary{background-color:#337ab7}.label-primary[href]:focus,.label-primary[href]:hover{background-color:#286090}.label-success{background-color:#5cb85c}.label-success[href]:focus,.label-success[href]:hover{background-color:#449d44}.label-info{background-color:#5bc0de}.label-info[href]:focus,.label-info[href]:hover{background-color:#31b0d5}.label-warning{background-color:#f0ad4e}.label-warning[href]:focus,.label-warning[href]:hover{background-color:#ec971f}.label-danger{background-color:#d9534f}.label-danger[href]:focus,.label-danger[href]:hover{background-color:#c9302c}.badge{display:inline-block;min-width:10px;padding:3px 7px;font-size:12px;font-weight:700;line-height:1;color:#fff;text-align:center;white-space:nowrap;vertical-align:middle;background-color:#777;border-radius:10px}.badge:empty{display:none}.btn .badge{position:relative;top:-1px}.btn-group-xs>.btn .badge,.btn-xs .badge{top:0;padding:1px 5px}a.badge:focus,a.badge:hover{color:#fff;text-decoration:none;cursor:pointer}.list-group-item.active>.badge,.nav-pills>.active>a>.badge{color:#337ab7;background-color:#fff}.list-group-item>.badge{float:right}.list-group-item>.badge+.badge{margin-right:5px}.nav-pills>li>a>.badge{margin-left:3px}.jumbotron{padding-top:30px;padding-bottom:30px;margin-bottom:30px;color:inherit;background-color:#eee}.jumbotron .h1,.jumbotron h1{color:inherit}.jumbotron p{margin-bottom:15px;font-size:21px;font-weight:200}.jumbotron>hr{border-top-color:#d5d5d5}.container .jumbotron,.container-fluid .jumbotron{padding-right:15px;padding-left:15px;border-radius:6px}.jumbotron .container{max-width:100%}@media screen and (min-width:768px){.jumbotron{padding-top:48px;padding-bottom:48px}.container .jumbotron,.container-fluid .jumbotron{padding-right:60px;padding-left:60px}.jumbotron .h1,.jumbotron h1{font-size:63px}}.thumbnail{display:block;padding:4px;margin-bottom:20px;line-height:1.42857143;background-color:#fff;border:1px solid #ddd;border-radius:4px;-webkit-transition:border .2s ease-in-out;-o-transition:border .2s ease-in-out;transition:border .2s ease-in-out}.thumbnail a>img,.thumbnail>img{margin-right:auto;margin-left:auto}a.thumbnail.active,a.thumbnail:focus,a.thumbnail:hover{border-color:#337ab7}.thumbnail .caption{padding:9px;color:#333}.alert{padding:15px;margin-bottom:20px;border:1px solid transparent;border-radius:4px}.alert h4{margin-top:0;color:inherit}.alert .alert-link{font-weight:700}.alert>p,.alert>ul{margin-bottom:0}.alert>p+p{margin-top:5px}.alert-dismissable,.alert-dismissible{padding-right:35px}.alert-dismissable .close,.alert-dismissible .close{position:relative;top:-2px;right:-21px;color:inherit}.alert-success{color:#3c763d;background-color:#dff0d8;border-color:#d6e9c6}.alert-success hr{border-top-color:#c9e2b3}.alert-success .alert-link{color:#2b542c}.alert-info{color:#31708f;background-color:#d9edf7;border-color:#bce8f1}.alert-info hr{border-top-color:#a6e1ec}.alert-info .alert-link{color:#245269}.alert-warning{color:#8a6d3b;background-color:#fcf8e3;border-color:#faebcc}.alert-warning hr{border-top-color:#f7e1b5}.alert-warning .alert-link{color:#66512c}.alert-danger{color:#a94442;background-color:#f2dede;border-color:#ebccd1}.alert-danger hr{border-top-color:#e4b9c0}.alert-danger .alert-link{color:#843534}@-webkit-keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}@-o-keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}@keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}.progress{height:20px;margin-bottom:20px;overflow:hidden;background-color:#f5f5f5;border-radius:4px;-webkit-box-shadow:inset 0 1px 2px rgba(0,0,0,.1);box-shadow:inset 0 1px 2px rgba(0,0,0,.1)}.progress-bar{float:left;width:0;height:100%;font-size:12px;line-height:20px;color:#fff;text-align:center;background-color:#337ab7;-webkit-box-shadow:inset 0 -1px 0 rgba(0,0,0,.15);box-shadow:inset 0 -1px 0 rgba(0,0,0,.15);-webkit-transition:width .6s ease;-o-transition:width .6s ease;transition:width .6s ease}.progress-bar-striped,.progress-striped .progress-bar{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);-webkit-background-size:40px 40px;background-size:40px 40px}.progress-bar.active,.progress.active .progress-bar{-webkit-animation:progress-bar-stripes 2s linear infinite;-o-animation:progress-bar-stripes 2s linear infinite;animation:progress-bar-stripes 2s linear infinite}.progress-bar-success{background-color:#5cb85c}.progress-striped .progress-bar-success{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent)}.progress-bar-info{background-color:#5bc0de}.progress-striped .progress-bar-info{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent)}.progress-bar-warning{background-color:#f0ad4e}.progress-striped .progress-bar-warning{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent)}.progress-bar-danger{background-color:#d9534f}.progress-striped .progress-bar-danger{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent)}.media{margin-top:15px}.media:first-child{margin-top:0}.media,.media-body{overflow:hidden;zoom:1}.media-body{width:10000px}.media-object{display:block}.media-object.img-thumbnail{max-width:none}.media-right,.media>.pull-right{padding-left:10px}.media-left,.media>.pull-left{padding-right:10px}.media-body,.media-left,.media-right{display:table-cell;vertical-align:top}.media-middle{vertical-align:middle}.media-bottom{vertical-align:bottom}.media-heading{margin-top:0;margin-bottom:5px}.media-list{padding-left:0;list-style:none}.list-group{padding-left:0;margin-bottom:20px}.list-group-item{position:relative;display:block;padding:10px 15px;margin-bottom:-1px;background-color:#fff;border:1px solid #ddd}.list-group-item:first-child{border-top-left-radius:4px;border-top-right-radius:4px}.list-group-item:last-child{margin-bottom:0;border-bottom-right-radius:4px;border-bottom-left-radius:4px}a.list-group-item,button.list-group-item{color:#555}a.list-group-item .list-group-item-heading,button.list-group-item .list-group-item-heading{color:#333}a.list-group-item:focus,a.list-group-item:hover,button.list-group-item:focus,button.list-group-item:hover{color:#555;text-decoration:none;background-color:#f5f5f5}button.list-group-item{width:100%;text-align:left}.list-group-item.disabled,.list-group-item.disabled:focus,.list-group-item.disabled:hover{color:#777;cursor:not-allowed;background-color:#eee}.list-group-item.disabled .list-group-item-heading,.list-group-item.disabled:focus .list-group-item-heading,.list-group-item.disabled:hover .list-group-item-heading{color:inherit}.list-group-item.disabled .list-group-item-text,.list-group-item.disabled:focus .list-group-item-text,.list-group-item.disabled:hover .list-group-item-text{color:#777}.list-group-item.active,.list-group-item.active:focus,.list-group-item.active:hover{z-index:2;color:#fff;background-color:#337ab7;border-color:#337ab7}.list-group-item.active .list-group-item-heading,.list-group-item.active .list-group-item-heading>.small,.list-group-item.active .list-group-item-heading>small,.list-group-item.active:focus .list-group-item-heading,.list-group-item.active:focus .list-group-item-heading>.small,.list-group-item.active:focus .list-group-item-heading>small,.list-group-item.active:hover .list-group-item-heading,.list-group-item.active:hover .list-group-item-heading>.small,.list-group-item.active:hover .list-group-item-heading>small{color:inherit}.list-group-item.active .list-group-item-text,.list-group-item.active:focus .list-group-item-text,.list-group-item.active:hover .list-group-item-text{color:#c7ddef}.list-group-item-success{color:#3c763d;background-color:#dff0d8}a.list-group-item-success,button.list-group-item-success{color:#3c763d}a.list-group-item-success .list-group-item-heading,button.list-group-item-success .list-group-item-heading{color:inherit}a.list-group-item-success:focus,a.list-group-item-success:hover,button.list-group-item-success:focus,button.list-group-item-success:hover{color:#3c763d;background-color:#d0e9c6}a.list-group-item-success.active,a.list-group-item-success.active:focus,a.list-group-item-success.active:hover,button.list-group-item-success.active,button.list-group-item-success.active:focus,button.list-group-item-success.active:hover{color:#fff;background-color:#3c763d;border-color:#3c763d}.list-group-item-info{color:#31708f;background-color:#d9edf7}a.list-group-item-info,button.list-group-item-info{color:#31708f}a.list-group-item-info .list-group-item-heading,button.list-group-item-info .list-group-item-heading{color:inherit}a.list-group-item-info:focus,a.list-group-item-info:hover,button.list-group-item-info:focus,button.list-group-item-info:hover{color:#31708f;background-color:#c4e3f3}a.list-group-item-info.active,a.list-group-item-info.active:focus,a.list-group-item-info.active:hover,button.list-group-item-info.active,button.list-group-item-info.active:focus,button.list-group-item-info.active:hover{color:#fff;background-color:#31708f;border-color:#31708f}.list-group-item-warning{color:#8a6d3b;background-color:#fcf8e3}a.list-group-item-warning,button.list-group-item-warning{color:#8a6d3b}a.list-group-item-warning .list-group-item-heading,button.list-group-item-warning .list-group-item-heading{color:inherit}a.list-group-item-warning:focus,a.list-group-item-warning:hover,button.list-group-item-warning:focus,button.list-group-item-warning:hover{color:#8a6d3b;background-color:#faf2cc}a.list-group-item-warning.active,a.list-group-item-warning.active:focus,a.list-group-item-warning.active:hover,button.list-group-item-warning.active,button.list-group-item-warning.active:focus,button.list-group-item-warning.active:hover{color:#fff;background-color:#8a6d3b;border-color:#8a6d3b}.list-group-item-danger{color:#a94442;background-color:#f2dede}a.list-group-item-danger,button.list-group-item-danger{color:#a94442}a.list-group-item-danger .list-group-item-heading,button.list-group-item-danger .list-group-item-heading{color:inherit}a.list-group-item-danger:focus,a.list-group-item-danger:hover,button.list-group-item-danger:focus,button.list-group-item-danger:hover{color:#a94442;background-color:#ebcccc}a.list-group-item-danger.active,a.list-group-item-danger.active:focus,a.list-group-item-danger.active:hover,button.list-group-item-danger.active,button.list-group-item-danger.active:focus,button.list-group-item-danger.active:hover{color:#fff;background-color:#a94442;border-color:#a94442}.list-group-item-heading{margin-top:0;margin-bottom:5px}.list-group-item-text{margin-bottom:0;line-height:1.3}.panel{margin-bottom:20px;background-color:#fff;border:1px solid transparent;border-radius:4px;-webkit-box-shadow:0 1px 1px rgba(0,0,0,.05);box-shadow:0 1px 1px rgba(0,0,0,.05)}.panel-body{padding:15px}.panel-heading{padding:10px 15px;border-bottom:1px solid transparent;border-top-left-radius:3px;border-top-right-radius:3px}.panel-heading>.dropdown .dropdown-toggle{color:inherit}.panel-title{margin-top:0;margin-bottom:0;font-size:16px;color:inherit}.panel-title>.small,.panel-title>.small>a,.panel-title>a,.panel-title>small,.panel-title>small>a{color:inherit}.panel-footer{padding:10px 15px;background-color:#f5f5f5;border-top:1px solid #ddd;border-bottom-right-radius:3px;border-bottom-left-radius:3px}.panel>.list-group,.panel>.panel-collapse>.list-group{margin-bottom:0}.panel>.list-group .list-group-item,.panel>.panel-collapse>.list-group .list-group-item{border-width:1px 0;border-radius:0}.panel>.list-group:first-child .list-group-item:first-child,.panel>.panel-collapse>.list-group:first-child .list-group-item:first-child{border-top:0;border-top-left-radius:3px;border-top-right-radius:3px}.panel>.list-group:last-child .list-group-item:last-child,.panel>.panel-collapse>.list-group:last-child .list-group-item:last-child{border-bottom:0;border-bottom-right-radius:3px;border-bottom-left-radius:3px}.panel>.panel-heading+.panel-collapse>.list-group .list-group-item:first-child{border-top-left-radius:0;border-top-right-radius:0}.panel-heading+.list-group .list-group-item:first-child{border-top-width:0}.list-group+.panel-footer{border-top-width:0}.panel>.panel-collapse>.table,.panel>.table,.panel>.table-responsive>.table{margin-bottom:0}.panel>.panel-collapse>.table caption,.panel>.table caption,.panel>.table-responsive>.table caption{padding-right:15px;padding-left:15px}.panel>.table-responsive:first-child>.table:first-child,.panel>.table:first-child{border-top-left-radius:3px;border-top-right-radius:3px}.panel>.table-responsive:first-child>.table:first-child>tbody:first-child>tr:first-child,.panel>.table-responsive:first-child>.table:first-child>thead:first-child>tr:first-child,.panel>.table:first-child>tbody:first-child>tr:first-child,.panel>.table:first-child>thead:first-child>tr:first-child{border-top-left-radius:3px;border-top-right-radius:3px}.panel>.table-responsive:first-child>.table:first-child>tbody:first-child>tr:first-child td:first-child,.panel>.table-responsive:first-child>.table:first-child>tbody:first-child>tr:first-child th:first-child,.panel>.table-responsive:first-child>.table:first-child>thead:first-child>tr:first-child td:first-child,.panel>.table-responsive:first-child>.table:first-child>thead:first-child>tr:first-child th:first-child,.panel>.table:first-child>tbody:first-child>tr:first-child td:first-child,.panel>.table:first-child>tbody:first-child>tr:first-child th:first-child,.panel>.table:first-child>thead:first-child>tr:first-child td:first-child,.panel>.table:first-child>thead:first-child>tr:first-child th:first-child{border-top-left-radius:3px}.panel>.table-responsive:first-child>.table:first-child>tbody:first-child>tr:first-child td:last-child,.panel>.table-responsive:first-child>.table:first-child>tbody:first-child>tr:first-child th:last-child,.panel>.table-responsive:first-child>.table:first-child>thead:first-child>tr:first-child td:last-child,.panel>.table-responsive:first-child>.table:first-child>thead:first-child>tr:first-child th:last-child,.panel>.table:first-child>tbody:first-child>tr:first-child td:last-child,.panel>.table:first-child>tbody:first-child>tr:first-child th:last-child,.panel>.table:first-child>thead:first-child>tr:first-child td:last-child,.panel>.table:first-child>thead:first-child>tr:first-child th:last-child{border-top-right-radius:3px}.panel>.table-responsive:last-child>.table:last-child,.panel>.table:last-child{border-bottom-right-radius:3px;border-bottom-left-radius:3px}.panel>.table-responsive:last-child>.table:last-child>tbody:last-child>tr:last-child,.panel>.table-responsive:last-child>.table:last-child>tfoot:last-child>tr:last-child,.panel>.table:last-child>tbody:last-child>tr:last-child,.panel>.table:last-child>tfoot:last-child>tr:last-child{border-bottom-right-radius:3px;border-bottom-left-radius:3px}.panel>.table-responsive:last-child>.table:last-child>tbody:last-child>tr:last-child td:first-child,.panel>.table-responsive:last-child>.table:last-child>tbody:last-child>tr:last-child th:first-child,.panel>.table-responsive:last-child>.table:last-child>tfoot:last-child>tr:last-child td:first-child,.panel>.table-responsive:last-child>.table:last-child>tfoot:last-child>tr:last-child th:first-child,.panel>.table:last-child>tbody:last-child>tr:last-child td:first-child,.panel>.table:last-child>tbody:last-child>tr:last-child th:first-child,.panel>.table:last-child>tfoot:last-child>tr:last-child td:first-child,.panel>.table:last-child>tfoot:last-child>tr:last-child th:first-child{border-bottom-left-radius:3px}.panel>.table-responsive:last-child>.table:last-child>tbody:last-child>tr:last-child td:last-child,.panel>.table-responsive:last-child>.table:last-child>tbody:last-child>tr:last-child th:last-child,.panel>.table-responsive:last-child>.table:last-child>tfoot:last-child>tr:last-child td:last-child,.panel>.table-responsive:last-child>.table:last-child>tfoot:last-child>tr:last-child th:last-child,.panel>.table:last-child>tbody:last-child>tr:last-child td:last-child,.panel>.table:last-child>tbody:last-child>tr:last-child th:last-child,.panel>.table:last-child>tfoot:last-child>tr:last-child td:last-child,.panel>.table:last-child>tfoot:last-child>tr:last-child th:last-child{border-bottom-right-radius:3px}.panel>.panel-body+.table,.panel>.panel-body+.table-responsive,.panel>.table+.panel-body,.panel>.table-responsive+.panel-body{border-top:1px solid #ddd}.panel>.table>tbody:first-child>tr:first-child td,.panel>.table>tbody:first-child>tr:first-child th{border-top:0}.panel>.table-bordered,.panel>.table-responsive>.table-bordered{border:0}.panel>.table-bordered>tbody>tr>td:first-child,.panel>.table-bordered>tbody>tr>th:first-child,.panel>.table-bordered>tfoot>tr>td:first-child,.panel>.table-bordered>tfoot>tr>th:first-child,.panel>.table-bordered>thead>tr>td:first-child,.panel>.table-bordered>thead>tr>th:first-child,.panel>.table-responsive>.table-bordered>tbody>tr>td:first-child,.panel>.table-responsive>.table-bordered>tbody>tr>th:first-child,.panel>.table-responsive>.table-bordered>tfoot>tr>td:first-child,.panel>.table-responsive>.table-bordered>tfoot>tr>th:first-child,.panel>.table-responsive>.table-bordered>thead>tr>td:first-child,.panel>.table-responsive>.table-bordered>thead>tr>th:first-child{border-left:0}.panel>.table-bordered>tbody>tr>td:last-child,.panel>.table-bordered>tbody>tr>th:last-child,.panel>.table-bordered>tfoot>tr>td:last-child,.panel>.table-bordered>tfoot>tr>th:last-child,.panel>.table-bordered>thead>tr>td:last-child,.panel>.table-bordered>thead>tr>th:last-child,.panel>.table-responsive>.table-bordered>tbody>tr>td:last-child,.panel>.table-responsive>.table-bordered>tbody>tr>th:last-child,.panel>.table-responsive>.table-bordered>tfoot>tr>td:last-child,.panel>.table-responsive>.table-bordered>tfoot>tr>th:last-child,.panel>.table-responsive>.table-bordered>thead>tr>td:last-child,.panel>.table-responsive>.table-bordered>thead>tr>th:last-child{border-right:0}.panel>.table-bordered>tbody>tr:first-child>td,.panel>.table-bordered>tbody>tr:first-child>th,.panel>.table-bordered>thead>tr:first-child>td,.panel>.table-bordered>thead>tr:first-child>th,.panel>.table-responsive>.table-bordered>tbody>tr:first-child>td,.panel>.table-responsive>.table-bordered>tbody>tr:first-child>th,.panel>.table-responsive>.table-bordered>thead>tr:first-child>td,.panel>.table-responsive>.table-bordered>thead>tr:first-child>th{border-bottom:0}.panel>.table-bordered>tbody>tr:last-child>td,.panel>.table-bordered>tbody>tr:last-child>th,.panel>.table-bordered>tfoot>tr:last-child>td,.panel>.table-bordered>tfoot>tr:last-child>th,.panel>.table-responsive>.table-bordered>tbody>tr:last-child>td,.panel>.table-responsive>.table-bordered>tbody>tr:last-child>th,.panel>.table-responsive>.table-bordered>tfoot>tr:last-child>td,.panel>.table-responsive>.table-bordered>tfoot>tr:last-child>th{border-bottom:0}.panel>.table-responsive{margin-bottom:0;border:0}.panel-group{margin-bottom:20px}.panel-group .panel{margin-bottom:0;border-radius:4px}.panel-group .panel+.panel{margin-top:5px}.panel-group .panel-heading{border-bottom:0}.panel-group .panel-heading+.panel-collapse>.list-group,.panel-group .panel-heading+.panel-collapse>.panel-body{border-top:1px solid #ddd}.panel-group .panel-footer{border-top:0}.panel-group .panel-footer+.panel-collapse .panel-body{border-bottom:1px solid #ddd}.panel-default{border-color:#ddd}.panel-default>.panel-heading{color:#333;background-color:#f5f5f5;border-color:#ddd}.panel-default>.panel-heading+.panel-collapse>.panel-body{border-top-color:#ddd}.panel-default>.panel-heading .badge{color:#f5f5f5;background-color:#333}.panel-default>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#ddd}.panel-primary{border-color:#337ab7}.panel-primary>.panel-heading{color:#fff;background-color:#337ab7;border-color:#337ab7}.panel-primary>.panel-heading+.panel-collapse>.panel-body{border-top-color:#337ab7}.panel-primary>.panel-heading .badge{color:#337ab7;background-color:#fff}.panel-primary>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#337ab7}.panel-success{border-color:#d6e9c6}.panel-success>.panel-heading{color:#3c763d;background-color:#dff0d8;border-color:#d6e9c6}.panel-success>.panel-heading+.panel-collapse>.panel-body{border-top-color:#d6e9c6}.panel-success>.panel-heading .badge{color:#dff0d8;background-color:#3c763d}.panel-success>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#d6e9c6}.panel-info{border-color:#bce8f1}.panel-info>.panel-heading{color:#31708f;background-color:#d9edf7;border-color:#bce8f1}.panel-info>.panel-heading+.panel-collapse>.panel-body{border-top-color:#bce8f1}.panel-info>.panel-heading .badge{color:#d9edf7;background-color:#31708f}.panel-info>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#bce8f1}.panel-warning{border-color:#faebcc}.panel-warning>.panel-heading{color:#8a6d3b;background-color:#fcf8e3;border-color:#faebcc}.panel-warning>.panel-heading+.panel-collapse>.panel-body{border-top-color:#faebcc}.panel-warning>.panel-heading .badge{color:#fcf8e3;background-color:#8a6d3b}.panel-warning>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#faebcc}.panel-danger{border-color:#ebccd1}.panel-danger>.panel-heading{color:#a94442;background-color:#f2dede;border-color:#ebccd1}.panel-danger>.panel-heading+.panel-collapse>.panel-body{border-top-color:#ebccd1}.panel-danger>.panel-heading .badge{color:#f2dede;background-color:#a94442}.panel-danger>.panel-footer+.panel-collapse>.panel-body{border-bottom-color:#ebccd1}.embed-responsive{position:relative;display:block;height:0;padding:0;overflow:hidden}.embed-responsive .embed-responsive-item,.embed-responsive embed,.embed-responsive iframe,.embed-responsive object,.embed-responsive video{position:absolute;top:0;bottom:0;left:0;width:100%;height:100%;border:0}.embed-responsive-16by9{padding-bottom:56.25%}.embed-responsive-4by3{padding-bottom:75%}.well{min-height:20px;padding:19px;margin-bottom:20px;background-color:#f5f5f5;border:1px solid #e3e3e3;border-radius:4px;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,.05);box-shadow:inset 0 1px 1px rgba(0,0,0,.05)}.well blockquote{border-color:#ddd;border-color:rgba(0,0,0,.15)}.well-lg{padding:24px;border-radius:6px}.well-sm{padding:9px;border-radius:3px}.close{float:right;font-size:21px;font-weight:700;line-height:1;color:#000;text-shadow:0 1px 0 #fff;filter:alpha(opacity=20);opacity:.2}.close:focus,.close:hover{color:#000;text-decoration:none;cursor:pointer;filter:alpha(opacity=50);opacity:.5}button.close{-webkit-appearance:none;padding:0;cursor:pointer;background:0 0;border:0}.modal-open{overflow:hidden}.modal{position:fixed;top:0;right:0;bottom:0;left:0;z-index:1050;display:none;overflow:hidden;-webkit-overflow-scrolling:touch;outline:0}.modal.fade .modal-dialog{-webkit-transition:-webkit-transform .3s ease-out;-o-transition:-o-transform .3s ease-out;transition:transform .3s ease-out;-webkit-transform:translate(0,-25%);-ms-transform:translate(0,-25%);-o-transform:translate(0,-25%);transform:translate(0,-25%)}.modal.in .modal-dialog{-webkit-transform:translate(0,0);-ms-transform:translate(0,0);-o-transform:translate(0,0);transform:translate(0,0)}.modal-open .modal{overflow-x:hidden;overflow-y:auto}.modal-dialog{position:relative;width:auto;margin:10px}.modal-content{position:relative;background-color:#fff;-webkit-background-clip:padding-box;background-clip:padding-box;border:1px solid #999;border:1px solid rgba(0,0,0,.2);border-radius:6px;outline:0;-webkit-box-shadow:0 3px 9px rgba(0,0,0,.5);box-shadow:0 3px 9px rgba(0,0,0,.5)}.modal-backdrop{position:fixed;top:0;right:0;bottom:0;left:0;z-index:1040;background-color:#000}.modal-backdrop.fade{filter:alpha(opacity=0);opacity:0}.modal-backdrop.in{filter:alpha(opacity=50);opacity:.5}.modal-header{padding:15px;border-bottom:1px solid #e5e5e5}.modal-header .close{margin-top:-2px}.modal-title{margin:0;line-height:1.42857143}.modal-body{position:relative;padding:15px}.modal-footer{padding:15px;text-align:right;border-top:1px solid #e5e5e5}.modal-footer .btn+.btn{margin-bottom:0;margin-left:5px}.modal-footer .btn-group .btn+.btn{margin-left:-1px}.modal-footer .btn-block+.btn-block{margin-left:0}.modal-scrollbar-measure{position:absolute;top:-9999px;width:50px;height:50px;overflow:scroll}@media (min-width:768px){.modal-dialog{width:600px;margin:30px auto}.modal-content{-webkit-box-shadow:0 5px 15px rgba(0,0,0,.5);box-shadow:0 5px 15px rgba(0,0,0,.5)}.modal-sm{width:300px}}@media (min-width:992px){.modal-lg{width:900px}}.tooltip{position:absolute;z-index:1070;display:block;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:12px;font-style:normal;font-weight:400;line-height:1.42857143;text-align:left;text-align:start;text-decoration:none;text-shadow:none;text-transform:none;letter-spacing:normal;word-break:normal;word-spacing:normal;word-wrap:normal;white-space:normal;filter:alpha(opacity=0);opacity:0;line-break:auto}.tooltip.in{filter:alpha(opacity=90);opacity:.9}.tooltip.top{padding:5px 0;margin-top:-3px}.tooltip.right{padding:0 5px;margin-left:3px}.tooltip.bottom{padding:5px 0;margin-top:3px}.tooltip.left{padding:0 5px;margin-left:-3px}.tooltip-inner{max-width:200px;padding:3px 8px;color:#fff;text-align:center;background-color:#000;border-radius:4px}.tooltip-arrow{position:absolute;width:0;height:0;border-color:transparent;border-style:solid}.tooltip.top .tooltip-arrow{bottom:0;left:50%;margin-left:-5px;border-width:5px 5px 0;border-top-color:#000}.tooltip.top-left .tooltip-arrow{right:5px;bottom:0;margin-bottom:-5px;border-width:5px 5px 0;border-top-color:#000}.tooltip.top-right .tooltip-arrow{bottom:0;left:5px;margin-bottom:-5px;border-width:5px 5px 0;border-top-color:#000}.tooltip.right .tooltip-arrow{top:50%;left:0;margin-top:-5px;border-width:5px 5px 5px 0;border-right-color:#000}.tooltip.left .tooltip-arrow{top:50%;right:0;margin-top:-5px;border-width:5px 0 5px 5px;border-left-color:#000}.tooltip.bottom .tooltip-arrow{top:0;left:50%;margin-left:-5px;border-width:0 5px 5px;border-bottom-color:#000}.tooltip.bottom-left .tooltip-arrow{top:0;right:5px;margin-top:-5px;border-width:0 5px 5px;border-bottom-color:#000}.tooltip.bottom-right .tooltip-arrow{top:0;left:5px;margin-top:-5px;border-width:0 5px 5px;border-bottom-color:#000}.popover{position:absolute;top:0;left:0;z-index:1060;display:none;max-width:276px;padding:1px;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;font-style:normal;font-weight:400;line-height:1.42857143;text-align:left;text-align:start;text-decoration:none;text-shadow:none;text-transform:none;letter-spacing:normal;word-break:normal;word-spacing:normal;word-wrap:normal;white-space:normal;background-color:#fff;-webkit-background-clip:padding-box;background-clip:padding-box;border:1px solid #ccc;border:1px solid rgba(0,0,0,.2);border-radius:6px;-webkit-box-shadow:0 5px 10px rgba(0,0,0,.2);box-shadow:0 5px 10px rgba(0,0,0,.2);line-break:auto}.popover.top{margin-top:-10px}.popover.right{margin-left:10px}.popover.bottom{margin-top:10px}.popover.left{margin-left:-10px}.popover-title{padding:8px 14px;margin:0;font-size:14px;background-color:#f7f7f7;border-bottom:1px solid #ebebeb;border-radius:5px 5px 0 0}.popover-content{padding:9px 14px}.popover>.arrow,.popover>.arrow:after{position:absolute;display:block;width:0;height:0;border-color:transparent;border-style:solid}.popover>.arrow{border-width:11px}.popover>.arrow:after{content:"";border-width:10px}.popover.top>.arrow{bottom:-11px;left:50%;margin-left:-11px;border-top-color:#999;border-top-color:rgba(0,0,0,.25);border-bottom-width:0}.popover.top>.arrow:after{bottom:1px;margin-left:-10px;content:" ";border-top-color:#fff;border-bottom-width:0}.popover.right>.arrow{top:50%;left:-11px;margin-top:-11px;border-right-color:#999;border-right-color:rgba(0,0,0,.25);border-left-width:0}.popover.right>.arrow:after{bottom:-10px;left:1px;content:" ";border-right-color:#fff;border-left-width:0}.popover.bottom>.arrow{top:-11px;left:50%;margin-left:-11px;border-top-width:0;border-bottom-color:#999;border-bottom-color:rgba(0,0,0,.25)}.popover.bottom>.arrow:after{top:1px;margin-left:-10px;content:" ";border-top-width:0;border-bottom-color:#fff}.popover.left>.arrow{top:50%;right:-11px;margin-top:-11px;border-right-width:0;border-left-color:#999;border-left-color:rgba(0,0,0,.25)}.popover.left>.arrow:after{right:1px;bottom:-10px;content:" ";border-right-width:0;border-left-color:#fff}.carousel{position:relative}.carousel-inner{position:relative;width:100%;overflow:hidden}.carousel-inner>.item{position:relative;display:none;-webkit-transition:.6s ease-in-out left;-o-transition:.6s ease-in-out left;transition:.6s ease-in-out left}.carousel-inner>.item>a>img,.carousel-inner>.item>img{line-height:1}@media all and (transform-3d),(-webkit-transform-3d){.carousel-inner>.item{-webkit-transition:-webkit-transform .6s ease-in-out;-o-transition:-o-transform .6s ease-in-out;transition:transform .6s ease-in-out;-webkit-backface-visibility:hidden;backface-visibility:hidden;-webkit-perspective:1000px;perspective:1000px}.carousel-inner>.item.active.right,.carousel-inner>.item.next{left:0;-webkit-transform:translate3d(100%,0,0);transform:translate3d(100%,0,0)}.carousel-inner>.item.active.left,.carousel-inner>.item.prev{left:0;-webkit-transform:translate3d(-100%,0,0);transform:translate3d(-100%,0,0)}.carousel-inner>.item.active,.carousel-inner>.item.next.left,.carousel-inner>.item.prev.right{left:0;-webkit-transform:translate3d(0,0,0);transform:translate3d(0,0,0)}}.carousel-inner>.active,.carousel-inner>.next,.carousel-inner>.prev{display:block}.carousel-inner>.active{left:0}.carousel-inner>.next,.carousel-inner>.prev{position:absolute;top:0;width:100%}.carousel-inner>.next{left:100%}.carousel-inner>.prev{left:-100%}.carousel-inner>.next.left,.carousel-inner>.prev.right{left:0}.carousel-inner>.active.left{left:-100%}.carousel-inner>.active.right{left:100%}.carousel-control{position:absolute;top:0;bottom:0;left:0;width:15%;font-size:20px;color:#fff;text-align:center;text-shadow:0 1px 2px rgba(0,0,0,.6);background-color:rgba(0,0,0,0);filter:alpha(opacity=50);opacity:.5}.carousel-control.left{background-image:-webkit-linear-gradient(left,rgba(0,0,0,.5) 0,rgba(0,0,0,.0001) 100%);background-image:-o-linear-gradient(left,rgba(0,0,0,.5) 0,rgba(0,0,0,.0001) 100%);background-image:-webkit-gradient(linear,left top,right top,from(rgba(0,0,0,.5)),to(rgba(0,0,0,.0001)));background-image:linear-gradient(to right,rgba(0,0,0,.5) 0,rgba(0,0,0,.0001) 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#80000000', endColorstr='#00000000', GradientType=1);background-repeat:repeat-x}.carousel-control.right{right:0;left:auto;background-image:-webkit-linear-gradient(left,rgba(0,0,0,.0001) 0,rgba(0,0,0,.5) 100%);background-image:-o-linear-gradient(left,rgba(0,0,0,.0001) 0,rgba(0,0,0,.5) 100%);background-image:-webkit-gradient(linear,left top,right top,from(rgba(0,0,0,.0001)),to(rgba(0,0,0,.5)));background-image:linear-gradient(to right,rgba(0,0,0,.0001) 0,rgba(0,0,0,.5) 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#00000000', endColorstr='#80000000', GradientType=1);background-repeat:repeat-x}.carousel-control:focus,.carousel-control:hover{color:#fff;text-decoration:none;filter:alpha(opacity=90);outline:0;opacity:.9}.carousel-control .glyphicon-chevron-left,.carousel-control .glyphicon-chevron-right,.carousel-control .icon-next,.carousel-control .icon-prev{position:absolute;top:50%;z-index:5;display:inline-block;margin-top:-10px}.carousel-control .glyphicon-chevron-left,.carousel-control .icon-prev{left:50%;margin-left:-10px}.carousel-control .glyphicon-chevron-right,.carousel-control .icon-next{right:50%;margin-right:-10px}.carousel-control .icon-next,.carousel-control .icon-prev{width:20px;height:20px;font-family:serif;line-height:1}.carousel-control .icon-prev:before{content:'\2039'}.carousel-control .icon-next:before{content:'\203a'}.carousel-indicators{position:absolute;bottom:10px;left:50%;z-index:15;width:60%;padding-left:0;margin-left:-30%;text-align:center;list-style:none}.carousel-indicators li{display:inline-block;width:10px;height:10px;margin:1px;text-indent:-999px;cursor:pointer;background-color:#000\9;background-color:rgba(0,0,0,0);border:1px solid #fff;border-radius:10px}.carousel-indicators .active{width:12px;height:12px;margin:0;background-color:#fff}.carousel-caption{position:absolute;right:15%;bottom:20px;left:15%;z-index:10;padding-top:20px;padding-bottom:20px;color:#fff;text-align:center;text-shadow:0 1px 2px rgba(0,0,0,.6)}.carousel-caption .btn{text-shadow:none}@media screen and (min-width:768px){.carousel-control .glyphicon-chevron-left,.carousel-control .glyphicon-chevron-right,.carousel-control .icon-next,.carousel-control .icon-prev{width:30px;height:30px;margin-top:-10px;font-size:30px}.carousel-control .glyphicon-chevron-left,.carousel-control .icon-prev{margin-left:-10px}.carousel-control .glyphicon-chevron-right,.carousel-control .icon-next{margin-right:-10px}.carousel-caption{right:20%;left:20%;padding-bottom:30px}.carousel-indicators{bottom:20px}}.btn-group-vertical>.btn-group:after,.btn-group-vertical>.btn-group:before,.btn-toolbar:after,.btn-toolbar:before,.clearfix:after,.clearfix:before,.container-fluid:after,.container-fluid:before,.container:after,.container:before,.dl-horizontal dd:after,.dl-horizontal dd:before,.form-horizontal .form-group:after,.form-horizontal .form-group:before,.modal-footer:after,.modal-footer:before,.modal-header:after,.modal-header:before,.nav:after,.nav:before,.navbar-collapse:after,.navbar-collapse:before,.navbar-header:after,.navbar-header:before,.navbar:after,.navbar:before,.pager:after,.pager:before,.panel-body:after,.panel-body:before,.row:after,.row:before{display:table;content:" "}.btn-group-vertical>.btn-group:after,.btn-toolbar:after,.clearfix:after,.container-fluid:after,.container:after,.dl-horizontal dd:after,.form-horizontal .form-group:after,.modal-footer:after,.modal-header:after,.nav:after,.navbar-collapse:after,.navbar-header:after,.navbar:after,.pager:after,.panel-body:after,.row:after{clear:both}.center-block{display:block;margin-right:auto;margin-left:auto}.pull-right{float:right!important}.pull-left{float:left!important}.hide{display:none!important}.show{display:block!important}.invisible{visibility:hidden}.text-hide{font:0/0 a;color:transparent;text-shadow:none;background-color:transparent;border:0}.hidden{display:none!important}.affix{position:fixed}@-ms-viewport{width:device-width}.visible-lg,.visible-md,.visible-sm,.visible-xs{display:none!important}.visible-lg-block,.visible-lg-inline,.visible-lg-inline-block,.visible-md-block,.visible-md-inline,.visible-md-inline-block,.visible-sm-block,.visible-sm-inline,.visible-sm-inline-block,.visible-xs-block,.visible-xs-inline,.visible-xs-inline-block{display:none!important}@media (max-width:767px){.visible-xs{display:block!important}table.visible-xs{display:table!important}tr.visible-xs{display:table-row!important}td.visible-xs,th.visible-xs{display:table-cell!important}}@media (max-width:767px){.visible-xs-block{display:block!important}}@media (max-width:767px){.visible-xs-inline{display:inline!important}}@media (max-width:767px){.visible-xs-inline-block{display:inline-block!important}}@media (min-width:768px) and (max-width:991px){.visible-sm{display:block!important}table.visible-sm{display:table!important}tr.visible-sm{display:table-row!important}td.visible-sm,th.visible-sm{display:table-cell!important}}@media (min-width:768px) and (max-width:991px){.visible-sm-block{display:block!important}}@media (min-width:768px) and (max-width:991px){.visible-sm-inline{display:inline!important}}@media (min-width:768px) and (max-width:991px){.visible-sm-inline-block{display:inline-block!important}}@media (min-width:992px) and (max-width:1199px){.visible-md{display:block!important}table.visible-md{display:table!important}tr.visible-md{display:table-row!important}td.visible-md,th.visible-md{display:table-cell!important}}@media (min-width:992px) and (max-width:1199px){.visible-md-block{display:block!important}}@media (min-width:992px) and (max-width:1199px){.visible-md-inline{display:inline!important}}@media (min-width:992px) and (max-width:1199px){.visible-md-inline-block{display:inline-block!important}}@media (min-width:1200px){.visible-lg{display:block!important}table.visible-lg{display:table!important}tr.visible-lg{display:table-row!important}td.visible-lg,th.visible-lg{display:table-cell!important}}@media (min-width:1200px){.visible-lg-block{display:block!important}}@media (min-width:1200px){.visible-lg-inline{display:inline!important}}@media (min-width:1200px){.visible-lg-inline-block{display:inline-block!important}}@media (max-width:767px){.hidden-xs{display:none!important}}@media (min-width:768px) and (max-width:991px){.hidden-sm{display:none!important}}@media (min-width:992px) and (max-width:1199px){.hidden-md{display:none!important}}@media (min-width:1200px){.hidden-lg{display:none!important}}.visible-print{display:none!important}@media print{.visible-print{display:block!important}table.visible-print{display:table!important}tr.visible-print{display:table-row!important}td.visible-print,th.visible-print{display:table-cell!important}}.visible-print-block{display:none!important}@media print{.visible-print-block{display:block!important}}.visible-print-inline{display:none!important}@media print{.visible-print-inline{display:inline!important}}.visible-print-inline-block{display:none!important}@media print{.visible-print-inline-block{display:inline-block!important}}@media print{.hidden-print{display:none!important}}
/*# sourceMappingURL=bootstrap.min.css.map */
/*!
 * Bootstrap v3.3.6 (http://getbootstrap.com)
 * Copyright 2011-2015 Twitter, Inc.
 * Licensed under the MIT license
 */
if("undefined"==typeof jQuery)throw new Error("Bootstrap's JavaScript requires jQuery");+function(a){"use strict";var b=a.fn.jquery.split(" ")[0].split(".");if(b[0]<2&&b[1]<9||1==b[0]&&9==b[1]&&b[2]<1||b[0]>2)throw new Error("Bootstrap's JavaScript requires jQuery version 1.9.1 or higher, but lower than version 3")}(jQuery),+function(a){"use strict";function b(){var a=document.createElement("bootstrap"),b={WebkitTransition:"webkitTransitionEnd",MozTransition:"transitionend",OTransition:"oTransitionEnd otransitionend",transition:"transitionend"};for(var c in b)if(void 0!==a.style[c])return{end:b[c]};return!1}a.fn.emulateTransitionEnd=function(b){var c=!1,d=this;a(this).one("bsTransitionEnd",function(){c=!0});var e=function(){c||a(d).trigger(a.support.transition.end)};return setTimeout(e,b),this},a(function(){a.support.transition=b(),a.support.transition&&(a.event.special.bsTransitionEnd={bindType:a.support.transition.end,delegateType:a.support.transition.end,handle:function(b){return a(b.target).is(this)?b.handleObj.handler.apply(this,arguments):void 0}})})}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var c=a(this),e=c.data("bs.alert");e||c.data("bs.alert",e=new d(this)),"string"==typeof b&&e[b].call(c)})}var c='[data-dismiss="alert"]',d=function(b){a(b).on("click",c,this.close)};d.VERSION="3.3.6",d.TRANSITION_DURATION=150,d.prototype.close=function(b){function c(){g.detach().trigger("closed.bs.alert").remove()}var e=a(this),f=e.attr("data-target");f||(f=e.attr("href"),f=f&&f.replace(/.*(?=#[^\s]*$)/,""));var g=a(f);b&&b.preventDefault(),g.length||(g=e.closest(".alert")),g.trigger(b=a.Event("close.bs.alert")),b.isDefaultPrevented()||(g.removeClass("in"),a.support.transition&&g.hasClass("fade")?g.one("bsTransitionEnd",c).emulateTransitionEnd(d.TRANSITION_DURATION):c())};var e=a.fn.alert;a.fn.alert=b,a.fn.alert.Constructor=d,a.fn.alert.noConflict=function(){return a.fn.alert=e,this},a(document).on("click.bs.alert.data-api",c,d.prototype.close)}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.button"),f="object"==typeof b&&b;e||d.data("bs.button",e=new c(this,f)),"toggle"==b?e.toggle():b&&e.setState(b)})}var c=function(b,d){this.$element=a(b),this.options=a.extend({},c.DEFAULTS,d),this.isLoading=!1};c.VERSION="3.3.6",c.DEFAULTS={loadingText:"loading..."},c.prototype.setState=function(b){var c="disabled",d=this.$element,e=d.is("input")?"val":"html",f=d.data();b+="Text",null==f.resetText&&d.data("resetText",d[e]()),setTimeout(a.proxy(function(){d[e](null==f[b]?this.options[b]:f[b]),"loadingText"==b?(this.isLoading=!0,d.addClass(c).attr(c,c)):this.isLoading&&(this.isLoading=!1,d.removeClass(c).removeAttr(c))},this),0)},c.prototype.toggle=function(){var a=!0,b=this.$element.closest('[data-toggle="buttons"]');if(b.length){var c=this.$element.find("input");"radio"==c.prop("type")?(c.prop("checked")&&(a=!1),b.find(".active").removeClass("active"),this.$element.addClass("active")):"checkbox"==c.prop("type")&&(c.prop("checked")!==this.$element.hasClass("active")&&(a=!1),this.$element.toggleClass("active")),c.prop("checked",this.$element.hasClass("active")),a&&c.trigger("change")}else this.$element.attr("aria-pressed",!this.$element.hasClass("active")),this.$element.toggleClass("active")};var d=a.fn.button;a.fn.button=b,a.fn.button.Constructor=c,a.fn.button.noConflict=function(){return a.fn.button=d,this},a(document).on("click.bs.button.data-api",'[data-toggle^="button"]',function(c){var d=a(c.target);d.hasClass("btn")||(d=d.closest(".btn")),b.call(d,"toggle"),a(c.target).is('input[type="radio"]')||a(c.target).is('input[type="checkbox"]')||c.preventDefault()}).on("focus.bs.button.data-api blur.bs.button.data-api",'[data-toggle^="button"]',function(b){a(b.target).closest(".btn").toggleClass("focus",/^focus(in)?$/.test(b.type))})}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.carousel"),f=a.extend({},c.DEFAULTS,d.data(),"object"==typeof b&&b),g="string"==typeof b?b:f.slide;e||d.data("bs.carousel",e=new c(this,f)),"number"==typeof b?e.to(b):g?e[g]():f.interval&&e.pause().cycle()})}var c=function(b,c){this.$element=a(b),this.$indicators=this.$element.find(".carousel-indicators"),this.options=c,this.paused=null,this.sliding=null,this.interval=null,this.$active=null,this.$items=null,this.options.keyboard&&this.$element.on("keydown.bs.carousel",a.proxy(this.keydown,this)),"hover"==this.options.pause&&!("ontouchstart"in document.documentElement)&&this.$element.on("mouseenter.bs.carousel",a.proxy(this.pause,this)).on("mouseleave.bs.carousel",a.proxy(this.cycle,this))};c.VERSION="3.3.6",c.TRANSITION_DURATION=600,c.DEFAULTS={interval:5e3,pause:"hover",wrap:!0,keyboard:!0},c.prototype.keydown=function(a){if(!/input|textarea/i.test(a.target.tagName)){switch(a.which){case 37:this.prev();break;case 39:this.next();break;default:return}a.preventDefault()}},c.prototype.cycle=function(b){return b||(this.paused=!1),this.interval&&clearInterval(this.interval),this.options.interval&&!this.paused&&(this.interval=setInterval(a.proxy(this.next,this),this.options.interval)),this},c.prototype.getItemIndex=function(a){return this.$items=a.parent().children(".item"),this.$items.index(a||this.$active)},c.prototype.getItemForDirection=function(a,b){var c=this.getItemIndex(b),d="prev"==a&&0===c||"next"==a&&c==this.$items.length-1;if(d&&!this.options.wrap)return b;var e="prev"==a?-1:1,f=(c+e)%this.$items.length;return this.$items.eq(f)},c.prototype.to=function(a){var b=this,c=this.getItemIndex(this.$active=this.$element.find(".item.active"));return a>this.$items.length-1||0>a?void 0:this.sliding?this.$element.one("slid.bs.carousel",function(){b.to(a)}):c==a?this.pause().cycle():this.slide(a>c?"next":"prev",this.$items.eq(a))},c.prototype.pause=function(b){return b||(this.paused=!0),this.$element.find(".next, .prev").length&&a.support.transition&&(this.$element.trigger(a.support.transition.end),this.cycle(!0)),this.interval=clearInterval(this.interval),this},c.prototype.next=function(){return this.sliding?void 0:this.slide("next")},c.prototype.prev=function(){return this.sliding?void 0:this.slide("prev")},c.prototype.slide=function(b,d){var e=this.$element.find(".item.active"),f=d||this.getItemForDirection(b,e),g=this.interval,h="next"==b?"left":"right",i=this;if(f.hasClass("active"))return this.sliding=!1;var j=f[0],k=a.Event("slide.bs.carousel",{relatedTarget:j,direction:h});if(this.$element.trigger(k),!k.isDefaultPrevented()){if(this.sliding=!0,g&&this.pause(),this.$indicators.length){this.$indicators.find(".active").removeClass("active");var l=a(this.$indicators.children()[this.getItemIndex(f)]);l&&l.addClass("active")}var m=a.Event("slid.bs.carousel",{relatedTarget:j,direction:h});return a.support.transition&&this.$element.hasClass("slide")?(f.addClass(b),f[0].offsetWidth,e.addClass(h),f.addClass(h),e.one("bsTransitionEnd",function(){f.removeClass([b,h].join(" ")).addClass("active"),e.removeClass(["active",h].join(" ")),i.sliding=!1,setTimeout(function(){i.$element.trigger(m)},0)}).emulateTransitionEnd(c.TRANSITION_DURATION)):(e.removeClass("active"),f.addClass("active"),this.sliding=!1,this.$element.trigger(m)),g&&this.cycle(),this}};var d=a.fn.carousel;a.fn.carousel=b,a.fn.carousel.Constructor=c,a.fn.carousel.noConflict=function(){return a.fn.carousel=d,this};var e=function(c){var d,e=a(this),f=a(e.attr("data-target")||(d=e.attr("href"))&&d.replace(/.*(?=#[^\s]+$)/,""));if(f.hasClass("carousel")){var g=a.extend({},f.data(),e.data()),h=e.attr("data-slide-to");h&&(g.interval=!1),b.call(f,g),h&&f.data("bs.carousel").to(h),c.preventDefault()}};a(document).on("click.bs.carousel.data-api","[data-slide]",e).on("click.bs.carousel.data-api","[data-slide-to]",e),a(window).on("load",function(){a('[data-ride="carousel"]').each(function(){var c=a(this);b.call(c,c.data())})})}(jQuery),+function(a){"use strict";function b(b){var c,d=b.attr("data-target")||(c=b.attr("href"))&&c.replace(/.*(?=#[^\s]+$)/,"");return a(d)}function c(b){return this.each(function(){var c=a(this),e=c.data("bs.collapse"),f=a.extend({},d.DEFAULTS,c.data(),"object"==typeof b&&b);!e&&f.toggle&&/show|hide/.test(b)&&(f.toggle=!1),e||c.data("bs.collapse",e=new d(this,f)),"string"==typeof b&&e[b]()})}var d=function(b,c){this.$element=a(b),this.options=a.extend({},d.DEFAULTS,c),this.$trigger=a('[data-toggle="collapse"][href="#'+b.id+'"],[data-toggle="collapse"][data-target="#'+b.id+'"]'),this.transitioning=null,this.options.parent?this.$parent=this.getParent():this.addAriaAndCollapsedClass(this.$element,this.$trigger),this.options.toggle&&this.toggle()};d.VERSION="3.3.6",d.TRANSITION_DURATION=350,d.DEFAULTS={toggle:!0},d.prototype.dimension=function(){var a=this.$element.hasClass("width");return a?"width":"height"},d.prototype.show=function(){if(!this.transitioning&&!this.$element.hasClass("in")){var b,e=this.$parent&&this.$parent.children(".panel").children(".in, .collapsing");if(!(e&&e.length&&(b=e.data("bs.collapse"),b&&b.transitioning))){var f=a.Event("show.bs.collapse");if(this.$element.trigger(f),!f.isDefaultPrevented()){e&&e.length&&(c.call(e,"hide"),b||e.data("bs.collapse",null));var g=this.dimension();this.$element.removeClass("collapse").addClass("collapsing")[g](0).attr("aria-expanded",!0),this.$trigger.removeClass("collapsed").attr("aria-expanded",!0),this.transitioning=1;var h=function(){this.$element.removeClass("collapsing").addClass("collapse in")[g](""),this.transitioning=0,this.$element.trigger("shown.bs.collapse")};if(!a.support.transition)return h.call(this);var i=a.camelCase(["scroll",g].join("-"));this.$element.one("bsTransitionEnd",a.proxy(h,this)).emulateTransitionEnd(d.TRANSITION_DURATION)[g](this.$element[0][i])}}}},d.prototype.hide=function(){if(!this.transitioning&&this.$element.hasClass("in")){var b=a.Event("hide.bs.collapse");if(this.$element.trigger(b),!b.isDefaultPrevented()){var c=this.dimension();this.$element[c](this.$element[c]())[0].offsetHeight,this.$element.addClass("collapsing").removeClass("collapse in").attr("aria-expanded",!1),this.$trigger.addClass("collapsed").attr("aria-expanded",!1),this.transitioning=1;var e=function(){this.transitioning=0,this.$element.removeClass("collapsing").addClass("collapse").trigger("hidden.bs.collapse")};return a.support.transition?void this.$element[c](0).one("bsTransitionEnd",a.proxy(e,this)).emulateTransitionEnd(d.TRANSITION_DURATION):e.call(this)}}},d.prototype.toggle=function(){this[this.$element.hasClass("in")?"hide":"show"]()},d.prototype.getParent=function(){return a(this.options.parent).find('[data-toggle="collapse"][data-parent="'+this.options.parent+'"]').each(a.proxy(function(c,d){var e=a(d);this.addAriaAndCollapsedClass(b(e),e)},this)).end()},d.prototype.addAriaAndCollapsedClass=function(a,b){var c=a.hasClass("in");a.attr("aria-expanded",c),b.toggleClass("collapsed",!c).attr("aria-expanded",c)};var e=a.fn.collapse;a.fn.collapse=c,a.fn.collapse.Constructor=d,a.fn.collapse.noConflict=function(){return a.fn.collapse=e,this},a(document).on("click.bs.collapse.data-api",'[data-toggle="collapse"]',function(d){var e=a(this);e.attr("data-target")||d.preventDefault();var f=b(e),g=f.data("bs.collapse"),h=g?"toggle":e.data();c.call(f,h)})}(jQuery),+function(a){"use strict";function b(b){var c=b.attr("data-target");c||(c=b.attr("href"),c=c&&/#[A-Za-z]/.test(c)&&c.replace(/.*(?=#[^\s]*$)/,""));var d=c&&a(c);return d&&d.length?d:b.parent()}function c(c){c&&3===c.which||(a(e).remove(),a(f).each(function(){var d=a(this),e=b(d),f={relatedTarget:this};e.hasClass("open")&&(c&&"click"==c.type&&/input|textarea/i.test(c.target.tagName)&&a.contains(e[0],c.target)||(e.trigger(c=a.Event("hide.bs.dropdown",f)),c.isDefaultPrevented()||(d.attr("aria-expanded","false"),e.removeClass("open").trigger(a.Event("hidden.bs.dropdown",f)))))}))}function d(b){return this.each(function(){var c=a(this),d=c.data("bs.dropdown");d||c.data("bs.dropdown",d=new g(this)),"string"==typeof b&&d[b].call(c)})}var e=".dropdown-backdrop",f='[data-toggle="dropdown"]',g=function(b){a(b).on("click.bs.dropdown",this.toggle)};g.VERSION="3.3.6",g.prototype.toggle=function(d){var e=a(this);if(!e.is(".disabled, :disabled")){var f=b(e),g=f.hasClass("open");if(c(),!g){"ontouchstart"in document.documentElement&&!f.closest(".navbar-nav").length&&a(document.createElement("div")).addClass("dropdown-backdrop").insertAfter(a(this)).on("click",c);var h={relatedTarget:this};if(f.trigger(d=a.Event("show.bs.dropdown",h)),d.isDefaultPrevented())return;e.trigger("focus").attr("aria-expanded","true"),f.toggleClass("open").trigger(a.Event("shown.bs.dropdown",h))}return!1}},g.prototype.keydown=function(c){if(/(38|40|27|32)/.test(c.which)&&!/input|textarea/i.test(c.target.tagName)){var d=a(this);if(c.preventDefault(),c.stopPropagation(),!d.is(".disabled, :disabled")){var e=b(d),g=e.hasClass("open");if(!g&&27!=c.which||g&&27==c.which)return 27==c.which&&e.find(f).trigger("focus"),d.trigger("click");var h=" li:not(.disabled):visible a",i=e.find(".dropdown-menu"+h);if(i.length){var j=i.index(c.target);38==c.which&&j>0&&j--,40==c.which&&j<i.length-1&&j++,~j||(j=0),i.eq(j).trigger("focus")}}}};var h=a.fn.dropdown;a.fn.dropdown=d,a.fn.dropdown.Constructor=g,a.fn.dropdown.noConflict=function(){return a.fn.dropdown=h,this},a(document).on("click.bs.dropdown.data-api",c).on("click.bs.dropdown.data-api",".dropdown form",function(a){a.stopPropagation()}).on("click.bs.dropdown.data-api",f,g.prototype.toggle).on("keydown.bs.dropdown.data-api",f,g.prototype.keydown).on("keydown.bs.dropdown.data-api",".dropdown-menu",g.prototype.keydown)}(jQuery),+function(a){"use strict";function b(b,d){return this.each(function(){var e=a(this),f=e.data("bs.modal"),g=a.extend({},c.DEFAULTS,e.data(),"object"==typeof b&&b);f||e.data("bs.modal",f=new c(this,g)),"string"==typeof b?f[b](d):g.show&&f.show(d)})}var c=function(b,c){this.options=c,this.$body=a(document.body),this.$element=a(b),this.$dialog=this.$element.find(".modal-dialog"),this.$backdrop=null,this.isShown=null,this.originalBodyPad=null,this.scrollbarWidth=0,this.ignoreBackdropClick=!1,this.options.remote&&this.$element.find(".modal-content").load(this.options.remote,a.proxy(function(){this.$element.trigger("loaded.bs.modal")},this))};c.VERSION="3.3.6",c.TRANSITION_DURATION=300,c.BACKDROP_TRANSITION_DURATION=150,c.DEFAULTS={backdrop:!0,keyboard:!0,show:!0},c.prototype.toggle=function(a){return this.isShown?this.hide():this.show(a)},c.prototype.show=function(b){var d=this,e=a.Event("show.bs.modal",{relatedTarget:b});this.$element.trigger(e),this.isShown||e.isDefaultPrevented()||(this.isShown=!0,this.checkScrollbar(),this.setScrollbar(),this.$body.addClass("modal-open"),this.escape(),this.resize(),this.$element.on("click.dismiss.bs.modal",'[data-dismiss="modal"]',a.proxy(this.hide,this)),this.$dialog.on("mousedown.dismiss.bs.modal",function(){d.$element.one("mouseup.dismiss.bs.modal",function(b){a(b.target).is(d.$element)&&(d.ignoreBackdropClick=!0)})}),this.backdrop(function(){var e=a.support.transition&&d.$element.hasClass("fade");d.$element.parent().length||d.$element.appendTo(d.$body),d.$element.show().scrollTop(0),d.adjustDialog(),e&&d.$element[0].offsetWidth,d.$element.addClass("in"),d.enforceFocus();var f=a.Event("shown.bs.modal",{relatedTarget:b});e?d.$dialog.one("bsTransitionEnd",function(){d.$element.trigger("focus").trigger(f)}).emulateTransitionEnd(c.TRANSITION_DURATION):d.$element.trigger("focus").trigger(f)}))},c.prototype.hide=function(b){b&&b.preventDefault(),b=a.Event("hide.bs.modal"),this.$element.trigger(b),this.isShown&&!b.isDefaultPrevented()&&(this.isShown=!1,this.escape(),this.resize(),a(document).off("focusin.bs.modal"),this.$element.removeClass("in").off("click.dismiss.bs.modal").off("mouseup.dismiss.bs.modal"),this.$dialog.off("mousedown.dismiss.bs.modal"),a.support.transition&&this.$element.hasClass("fade")?this.$element.one("bsTransitionEnd",a.proxy(this.hideModal,this)).emulateTransitionEnd(c.TRANSITION_DURATION):this.hideModal())},c.prototype.enforceFocus=function(){a(document).off("focusin.bs.modal").on("focusin.bs.modal",a.proxy(function(a){this.$element[0]===a.target||this.$element.has(a.target).length||this.$element.trigger("focus")},this))},c.prototype.escape=function(){this.isShown&&this.options.keyboard?this.$element.on("keydown.dismiss.bs.modal",a.proxy(function(a){27==a.which&&this.hide()},this)):this.isShown||this.$element.off("keydown.dismiss.bs.modal")},c.prototype.resize=function(){this.isShown?a(window).on("resize.bs.modal",a.proxy(this.handleUpdate,this)):a(window).off("resize.bs.modal")},c.prototype.hideModal=function(){var a=this;this.$element.hide(),this.backdrop(function(){a.$body.removeClass("modal-open"),a.resetAdjustments(),a.resetScrollbar(),a.$element.trigger("hidden.bs.modal")})},c.prototype.removeBackdrop=function(){this.$backdrop&&this.$backdrop.remove(),this.$backdrop=null},c.prototype.backdrop=function(b){var d=this,e=this.$element.hasClass("fade")?"fade":"";if(this.isShown&&this.options.backdrop){var f=a.support.transition&&e;if(this.$backdrop=a(document.createElement("div")).addClass("modal-backdrop "+e).appendTo(this.$body),this.$element.on("click.dismiss.bs.modal",a.proxy(function(a){return this.ignoreBackdropClick?void(this.ignoreBackdropClick=!1):void(a.target===a.currentTarget&&("static"==this.options.backdrop?this.$element[0].focus():this.hide()))},this)),f&&this.$backdrop[0].offsetWidth,this.$backdrop.addClass("in"),!b)return;f?this.$backdrop.one("bsTransitionEnd",b).emulateTransitionEnd(c.BACKDROP_TRANSITION_DURATION):b()}else if(!this.isShown&&this.$backdrop){this.$backdrop.removeClass("in");var g=function(){d.removeBackdrop(),b&&b()};a.support.transition&&this.$element.hasClass("fade")?this.$backdrop.one("bsTransitionEnd",g).emulateTransitionEnd(c.BACKDROP_TRANSITION_DURATION):g()}else b&&b()},c.prototype.handleUpdate=function(){this.adjustDialog()},c.prototype.adjustDialog=function(){var a=this.$element[0].scrollHeight>document.documentElement.clientHeight;this.$element.css({paddingLeft:!this.bodyIsOverflowing&&a?this.scrollbarWidth:"",paddingRight:this.bodyIsOverflowing&&!a?this.scrollbarWidth:""})},c.prototype.resetAdjustments=function(){this.$element.css({paddingLeft:"",paddingRight:""})},c.prototype.checkScrollbar=function(){var a=window.innerWidth;if(!a){var b=document.documentElement.getBoundingClientRect();a=b.right-Math.abs(b.left)}this.bodyIsOverflowing=document.body.clientWidth<a,this.scrollbarWidth=this.measureScrollbar()},c.prototype.setScrollbar=function(){var a=parseInt(this.$body.css("padding-right")||0,10);this.originalBodyPad=document.body.style.paddingRight||"",this.bodyIsOverflowing&&this.$body.css("padding-right",a+this.scrollbarWidth)},c.prototype.resetScrollbar=function(){this.$body.css("padding-right",this.originalBodyPad)},c.prototype.measureScrollbar=function(){var a=document.createElement("div");a.className="modal-scrollbar-measure",this.$body.append(a);var b=a.offsetWidth-a.clientWidth;return this.$body[0].removeChild(a),b};var d=a.fn.modal;a.fn.modal=b,a.fn.modal.Constructor=c,a.fn.modal.noConflict=function(){return a.fn.modal=d,this},a(document).on("click.bs.modal.data-api",'[data-toggle="modal"]',function(c){var d=a(this),e=d.attr("href"),f=a(d.attr("data-target")||e&&e.replace(/.*(?=#[^\s]+$)/,"")),g=f.data("bs.modal")?"toggle":a.extend({remote:!/#/.test(e)&&e},f.data(),d.data());d.is("a")&&c.preventDefault(),f.one("show.bs.modal",function(a){a.isDefaultPrevented()||f.one("hidden.bs.modal",function(){d.is(":visible")&&d.trigger("focus")})}),b.call(f,g,this)})}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.tooltip"),f="object"==typeof b&&b;(e||!/destroy|hide/.test(b))&&(e||d.data("bs.tooltip",e=new c(this,f)),"string"==typeof b&&e[b]())})}var c=function(a,b){this.type=null,this.options=null,this.enabled=null,this.timeout=null,this.hoverState=null,this.$element=null,this.inState=null,this.init("tooltip",a,b)};c.VERSION="3.3.6",c.TRANSITION_DURATION=150,c.DEFAULTS={animation:!0,placement:"top",selector:!1,template:'<div class="tooltip" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>',trigger:"hover focus",title:"",delay:0,html:!1,container:!1,viewport:{selector:"body",padding:0}},c.prototype.init=function(b,c,d){if(this.enabled=!0,this.type=b,this.$element=a(c),this.options=this.getOptions(d),this.$viewport=this.options.viewport&&a(a.isFunction(this.options.viewport)?this.options.viewport.call(this,this.$element):this.options.viewport.selector||this.options.viewport),this.inState={click:!1,hover:!1,focus:!1},this.$element[0]instanceof document.constructor&&!this.options.selector)throw new Error("`selector` option must be specified when initializing "+this.type+" on the window.document object!");for(var e=this.options.trigger.split(" "),f=e.length;f--;){var g=e[f];if("click"==g)this.$element.on("click."+this.type,this.options.selector,a.proxy(this.toggle,this));else if("manual"!=g){var h="hover"==g?"mouseenter":"focusin",i="hover"==g?"mouseleave":"focusout";this.$element.on(h+"."+this.type,this.options.selector,a.proxy(this.enter,this)),this.$element.on(i+"."+this.type,this.options.selector,a.proxy(this.leave,this))}}this.options.selector?this._options=a.extend({},this.options,{trigger:"manual",selector:""}):this.fixTitle()},c.prototype.getDefaults=function(){return c.DEFAULTS},c.prototype.getOptions=function(b){return b=a.extend({},this.getDefaults(),this.$element.data(),b),b.delay&&"number"==typeof b.delay&&(b.delay={show:b.delay,hide:b.delay}),b},c.prototype.getDelegateOptions=function(){var b={},c=this.getDefaults();return this._options&&a.each(this._options,function(a,d){c[a]!=d&&(b[a]=d)}),b},c.prototype.enter=function(b){var c=b instanceof this.constructor?b:a(b.currentTarget).data("bs."+this.type);return c||(c=new this.constructor(b.currentTarget,this.getDelegateOptions()),a(b.currentTarget).data("bs."+this.type,c)),b instanceof a.Event&&(c.inState["focusin"==b.type?"focus":"hover"]=!0),c.tip().hasClass("in")||"in"==c.hoverState?void(c.hoverState="in"):(clearTimeout(c.timeout),c.hoverState="in",c.options.delay&&c.options.delay.show?void(c.timeout=setTimeout(function(){"in"==c.hoverState&&c.show()},c.options.delay.show)):c.show())},c.prototype.isInStateTrue=function(){for(var a in this.inState)if(this.inState[a])return!0;return!1},c.prototype.leave=function(b){var c=b instanceof this.constructor?b:a(b.currentTarget).data("bs."+this.type);return c||(c=new this.constructor(b.currentTarget,this.getDelegateOptions()),a(b.currentTarget).data("bs."+this.type,c)),b instanceof a.Event&&(c.inState["focusout"==b.type?"focus":"hover"]=!1),c.isInStateTrue()?void 0:(clearTimeout(c.timeout),c.hoverState="out",c.options.delay&&c.options.delay.hide?void(c.timeout=setTimeout(function(){"out"==c.hoverState&&c.hide()},c.options.delay.hide)):c.hide())},c.prototype.show=function(){var b=a.Event("show.bs."+this.type);if(this.hasContent()&&this.enabled){this.$element.trigger(b);var d=a.contains(this.$element[0].ownerDocument.documentElement,this.$element[0]);if(b.isDefaultPrevented()||!d)return;var e=this,f=this.tip(),g=this.getUID(this.type);this.setContent(),f.attr("id",g),this.$element.attr("aria-describedby",g),this.options.animation&&f.addClass("fade");var h="function"==typeof this.options.placement?this.options.placement.call(this,f[0],this.$element[0]):this.options.placement,i=/\s?auto?\s?/i,j=i.test(h);j&&(h=h.replace(i,"")||"top"),f.detach().css({top:0,left:0,display:"block"}).addClass(h).data("bs."+this.type,this),this.options.container?f.appendTo(this.options.container):f.insertAfter(this.$element),this.$element.trigger("inserted.bs."+this.type);var k=this.getPosition(),l=f[0].offsetWidth,m=f[0].offsetHeight;if(j){var n=h,o=this.getPosition(this.$viewport);h="bottom"==h&&k.bottom+m>o.bottom?"top":"top"==h&&k.top-m<o.top?"bottom":"right"==h&&k.right+l>o.width?"left":"left"==h&&k.left-l<o.left?"right":h,f.removeClass(n).addClass(h)}var p=this.getCalculatedOffset(h,k,l,m);this.applyPlacement(p,h);var q=function(){var a=e.hoverState;e.$element.trigger("shown.bs."+e.type),e.hoverState=null,"out"==a&&e.leave(e)};a.support.transition&&this.$tip.hasClass("fade")?f.one("bsTransitionEnd",q).emulateTransitionEnd(c.TRANSITION_DURATION):q()}},c.prototype.applyPlacement=function(b,c){var d=this.tip(),e=d[0].offsetWidth,f=d[0].offsetHeight,g=parseInt(d.css("margin-top"),10),h=parseInt(d.css("margin-left"),10);isNaN(g)&&(g=0),isNaN(h)&&(h=0),b.top+=g,b.left+=h,a.offset.setOffset(d[0],a.extend({using:function(a){d.css({top:Math.round(a.top),left:Math.round(a.left)})}},b),0),d.addClass("in");var i=d[0].offsetWidth,j=d[0].offsetHeight;"top"==c&&j!=f&&(b.top=b.top+f-j);var k=this.getViewportAdjustedDelta(c,b,i,j);k.left?b.left+=k.left:b.top+=k.top;var l=/top|bottom/.test(c),m=l?2*k.left-e+i:2*k.top-f+j,n=l?"offsetWidth":"offsetHeight";d.offset(b),this.replaceArrow(m,d[0][n],l)},c.prototype.replaceArrow=function(a,b,c){this.arrow().css(c?"left":"top",50*(1-a/b)+"%").css(c?"top":"left","")},c.prototype.setContent=function(){var a=this.tip(),b=this.getTitle();a.find(".tooltip-inner")[this.options.html?"html":"text"](b),a.removeClass("fade in top bottom left right")},c.prototype.hide=function(b){function d(){"in"!=e.hoverState&&f.detach(),e.$element.removeAttr("aria-describedby").trigger("hidden.bs."+e.type),b&&b()}var e=this,f=a(this.$tip),g=a.Event("hide.bs."+this.type);return this.$element.trigger(g),g.isDefaultPrevented()?void 0:(f.removeClass("in"),a.support.transition&&f.hasClass("fade")?f.one("bsTransitionEnd",d).emulateTransitionEnd(c.TRANSITION_DURATION):d(),this.hoverState=null,this)},c.prototype.fixTitle=function(){var a=this.$element;(a.attr("title")||"string"!=typeof a.attr("data-original-title"))&&a.attr("data-original-title",a.attr("title")||"").attr("title","")},c.prototype.hasContent=function(){return this.getTitle()},c.prototype.getPosition=function(b){b=b||this.$element;var c=b[0],d="BODY"==c.tagName,e=c.getBoundingClientRect();null==e.width&&(e=a.extend({},e,{width:e.right-e.left,height:e.bottom-e.top}));var f=d?{top:0,left:0}:b.offset(),g={scroll:d?document.documentElement.scrollTop||document.body.scrollTop:b.scrollTop()},h=d?{width:a(window).width(),height:a(window).height()}:null;return a.extend({},e,g,h,f)},c.prototype.getCalculatedOffset=function(a,b,c,d){return"bottom"==a?{top:b.top+b.height,left:b.left+b.width/2-c/2}:"top"==a?{top:b.top-d,left:b.left+b.width/2-c/2}:"left"==a?{top:b.top+b.height/2-d/2,left:b.left-c}:{top:b.top+b.height/2-d/2,left:b.left+b.width}},c.prototype.getViewportAdjustedDelta=function(a,b,c,d){var e={top:0,left:0};if(!this.$viewport)return e;var f=this.options.viewport&&this.options.viewport.padding||0,g=this.getPosition(this.$viewport);if(/right|left/.test(a)){var h=b.top-f-g.scroll,i=b.top+f-g.scroll+d;h<g.top?e.top=g.top-h:i>g.top+g.height&&(e.top=g.top+g.height-i)}else{var j=b.left-f,k=b.left+f+c;j<g.left?e.left=g.left-j:k>g.right&&(e.left=g.left+g.width-k)}return e},c.prototype.getTitle=function(){var a,b=this.$element,c=this.options;return a=b.attr("data-original-title")||("function"==typeof c.title?c.title.call(b[0]):c.title)},c.prototype.getUID=function(a){do a+=~~(1e6*Math.random());while(document.getElementById(a));return a},c.prototype.tip=function(){if(!this.$tip&&(this.$tip=a(this.options.template),1!=this.$tip.length))throw new Error(this.type+" `template` option must consist of exactly 1 top-level element!");return this.$tip},c.prototype.arrow=function(){return this.$arrow=this.$arrow||this.tip().find(".tooltip-arrow")},c.prototype.enable=function(){this.enabled=!0},c.prototype.disable=function(){this.enabled=!1},c.prototype.toggleEnabled=function(){this.enabled=!this.enabled},c.prototype.toggle=function(b){var c=this;b&&(c=a(b.currentTarget).data("bs."+this.type),c||(c=new this.constructor(b.currentTarget,this.getDelegateOptions()),a(b.currentTarget).data("bs."+this.type,c))),b?(c.inState.click=!c.inState.click,c.isInStateTrue()?c.enter(c):c.leave(c)):c.tip().hasClass("in")?c.leave(c):c.enter(c)},c.prototype.destroy=function(){var a=this;clearTimeout(this.timeout),this.hide(function(){a.$element.off("."+a.type).removeData("bs."+a.type),a.$tip&&a.$tip.detach(),a.$tip=null,a.$arrow=null,a.$viewport=null})};var d=a.fn.tooltip;a.fn.tooltip=b,a.fn.tooltip.Constructor=c,a.fn.tooltip.noConflict=function(){return a.fn.tooltip=d,this}}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.popover"),f="object"==typeof b&&b;(e||!/destroy|hide/.test(b))&&(e||d.data("bs.popover",e=new c(this,f)),"string"==typeof b&&e[b]())})}var c=function(a,b){this.init("popover",a,b)};if(!a.fn.tooltip)throw new Error("Popover requires tooltip.js");c.VERSION="3.3.6",c.DEFAULTS=a.extend({},a.fn.tooltip.Constructor.DEFAULTS,{placement:"right",trigger:"click",content:"",template:'<div class="popover" role="tooltip"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>'}),c.prototype=a.extend({},a.fn.tooltip.Constructor.prototype),c.prototype.constructor=c,c.prototype.getDefaults=function(){return c.DEFAULTS},c.prototype.setContent=function(){var a=this.tip(),b=this.getTitle(),c=this.getContent();a.find(".popover-title")[this.options.html?"html":"text"](b),a.find(".popover-content").children().detach().end()[this.options.html?"string"==typeof c?"html":"append":"text"](c),a.removeClass("fade top bottom left right in"),a.find(".popover-title").html()||a.find(".popover-title").hide()},c.prototype.hasContent=function(){return this.getTitle()||this.getContent()},c.prototype.getContent=function(){var a=this.$element,b=this.options;return a.attr("data-content")||("function"==typeof b.content?b.content.call(a[0]):b.content)},c.prototype.arrow=function(){return this.$arrow=this.$arrow||this.tip().find(".arrow")};var d=a.fn.popover;a.fn.popover=b,a.fn.popover.Constructor=c,a.fn.popover.noConflict=function(){return a.fn.popover=d,this}}(jQuery),+function(a){"use strict";function b(c,d){this.$body=a(document.body),this.$scrollElement=a(a(c).is(document.body)?window:c),this.options=a.extend({},b.DEFAULTS,d),this.selector=(this.options.target||"")+" .nav li > a",this.offsets=[],this.targets=[],this.activeTarget=null,this.scrollHeight=0,this.$scrollElement.on("scroll.bs.scrollspy",a.proxy(this.process,this)),this.refresh(),this.process()}function c(c){return this.each(function(){var d=a(this),e=d.data("bs.scrollspy"),f="object"==typeof c&&c;e||d.data("bs.scrollspy",e=new b(this,f)),"string"==typeof c&&e[c]()})}b.VERSION="3.3.6",b.DEFAULTS={offset:10},b.prototype.getScrollHeight=function(){return this.$scrollElement[0].scrollHeight||Math.max(this.$body[0].scrollHeight,document.documentElement.scrollHeight)},b.prototype.refresh=function(){var b=this,c="offset",d=0;this.offsets=[],this.targets=[],this.scrollHeight=this.getScrollHeight(),a.isWindow(this.$scrollElement[0])||(c="position",d=this.$scrollElement.scrollTop()),this.$body.find(this.selector).map(function(){var b=a(this),e=b.data("target")||b.attr("href"),f=/^#./.test(e)&&a(e);return f&&f.length&&f.is(":visible")&&[[f[c]().top+d,e]]||null}).sort(function(a,b){return a[0]-b[0]}).each(function(){b.offsets.push(this[0]),b.targets.push(this[1])})},b.prototype.process=function(){var a,b=this.$scrollElement.scrollTop()+this.options.offset,c=this.getScrollHeight(),d=this.options.offset+c-this.$scrollElement.height(),e=this.offsets,f=this.targets,g=this.activeTarget;if(this.scrollHeight!=c&&this.refresh(),b>=d)return g!=(a=f[f.length-1])&&this.activate(a);if(g&&b<e[0])return this.activeTarget=null,this.clear();for(a=e.length;a--;)g!=f[a]&&b>=e[a]&&(void 0===e[a+1]||b<e[a+1])&&this.activate(f[a])},b.prototype.activate=function(b){this.activeTarget=b,this.clear();var c=this.selector+'[data-target="'+b+'"],'+this.selector+'[href="'+b+'"]',d=a(c).parents("li").addClass("active");
d.parent(".dropdown-menu").length&&(d=d.closest("li.dropdown").addClass("active")),d.trigger("activate.bs.scrollspy")},b.prototype.clear=function(){a(this.selector).parentsUntil(this.options.target,".active").removeClass("active")};var d=a.fn.scrollspy;a.fn.scrollspy=c,a.fn.scrollspy.Constructor=b,a.fn.scrollspy.noConflict=function(){return a.fn.scrollspy=d,this},a(window).on("load.bs.scrollspy.data-api",function(){a('[data-spy="scroll"]').each(function(){var b=a(this);c.call(b,b.data())})})}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.tab");e||d.data("bs.tab",e=new c(this)),"string"==typeof b&&e[b]()})}var c=function(b){this.element=a(b)};c.VERSION="3.3.6",c.TRANSITION_DURATION=150,c.prototype.show=function(){var b=this.element,c=b.closest("ul:not(.dropdown-menu)"),d=b.data("target");if(d||(d=b.attr("href"),d=d&&d.replace(/.*(?=#[^\s]*$)/,"")),!b.parent("li").hasClass("active")){var e=c.find(".active:last a"),f=a.Event("hide.bs.tab",{relatedTarget:b[0]}),g=a.Event("show.bs.tab",{relatedTarget:e[0]});if(e.trigger(f),b.trigger(g),!g.isDefaultPrevented()&&!f.isDefaultPrevented()){var h=a(d);this.activate(b.closest("li"),c),this.activate(h,h.parent(),function(){e.trigger({type:"hidden.bs.tab",relatedTarget:b[0]}),b.trigger({type:"shown.bs.tab",relatedTarget:e[0]})})}}},c.prototype.activate=function(b,d,e){function f(){g.removeClass("active").find("> .dropdown-menu > .active").removeClass("active").end().find('[data-toggle="tab"]').attr("aria-expanded",!1),b.addClass("active").find('[data-toggle="tab"]').attr("aria-expanded",!0),h?(b[0].offsetWidth,b.addClass("in")):b.removeClass("fade"),b.parent(".dropdown-menu").length&&b.closest("li.dropdown").addClass("active").end().find('[data-toggle="tab"]').attr("aria-expanded",!0),e&&e()}var g=d.find("> .active"),h=e&&a.support.transition&&(g.length&&g.hasClass("fade")||!!d.find("> .fade").length);g.length&&h?g.one("bsTransitionEnd",f).emulateTransitionEnd(c.TRANSITION_DURATION):f(),g.removeClass("in")};var d=a.fn.tab;a.fn.tab=b,a.fn.tab.Constructor=c,a.fn.tab.noConflict=function(){return a.fn.tab=d,this};var e=function(c){c.preventDefault(),b.call(a(this),"show")};a(document).on("click.bs.tab.data-api",'[data-toggle="tab"]',e).on("click.bs.tab.data-api",'[data-toggle="pill"]',e)}(jQuery),+function(a){"use strict";function b(b){return this.each(function(){var d=a(this),e=d.data("bs.affix"),f="object"==typeof b&&b;e||d.data("bs.affix",e=new c(this,f)),"string"==typeof b&&e[b]()})}var c=function(b,d){this.options=a.extend({},c.DEFAULTS,d),this.$target=a(this.options.target).on("scroll.bs.affix.data-api",a.proxy(this.checkPosition,this)).on("click.bs.affix.data-api",a.proxy(this.checkPositionWithEventLoop,this)),this.$element=a(b),this.affixed=null,this.unpin=null,this.pinnedOffset=null,this.checkPosition()};c.VERSION="3.3.6",c.RESET="affix affix-top affix-bottom",c.DEFAULTS={offset:0,target:window},c.prototype.getState=function(a,b,c,d){var e=this.$target.scrollTop(),f=this.$element.offset(),g=this.$target.height();if(null!=c&&"top"==this.affixed)return c>e?"top":!1;if("bottom"==this.affixed)return null!=c?e+this.unpin<=f.top?!1:"bottom":a-d>=e+g?!1:"bottom";var h=null==this.affixed,i=h?e:f.top,j=h?g:b;return null!=c&&c>=e?"top":null!=d&&i+j>=a-d?"bottom":!1},c.prototype.getPinnedOffset=function(){if(this.pinnedOffset)return this.pinnedOffset;this.$element.removeClass(c.RESET).addClass("affix");var a=this.$target.scrollTop(),b=this.$element.offset();return this.pinnedOffset=b.top-a},c.prototype.checkPositionWithEventLoop=function(){setTimeout(a.proxy(this.checkPosition,this),1)},c.prototype.checkPosition=function(){if(this.$element.is(":visible")){var b=this.$element.height(),d=this.options.offset,e=d.top,f=d.bottom,g=Math.max(a(document).height(),a(document.body).height());"object"!=typeof d&&(f=e=d),"function"==typeof e&&(e=d.top(this.$element)),"function"==typeof f&&(f=d.bottom(this.$element));var h=this.getState(g,b,e,f);if(this.affixed!=h){null!=this.unpin&&this.$element.css("top","");var i="affix"+(h?"-"+h:""),j=a.Event(i+".bs.affix");if(this.$element.trigger(j),j.isDefaultPrevented())return;this.affixed=h,this.unpin="bottom"==h?this.getPinnedOffset():null,this.$element.removeClass(c.RESET).addClass(i).trigger(i.replace("affix","affixed")+".bs.affix")}"bottom"==h&&this.$element.offset({top:g-b-f})}};var d=a.fn.affix;a.fn.affix=b,a.fn.affix.Constructor=c,a.fn.affix.noConflict=function(){return a.fn.affix=d,this},a(window).on("load",function(){a('[data-spy="affix"]').each(function(){var c=a(this),d=c.data();d.offset=d.offset||{},null!=d.offsetBottom&&(d.offset.bottom=d.offsetBottom),null!=d.offsetTop&&(d.offset.top=d.offsetTop),b.call(c,d)})})}(jQuery);
/*!
 * Bootstrap v3.3.6 (http://getbootstrap.com)
 * Copyright 2011-2015 Twitter, Inc.
 * Licensed under MIT (https://github.com/twbs/bootstrap/blob/master/LICENSE)
 */.btn-danger,.btn-default,.btn-info,.btn-primary,.btn-success,.btn-warning{text-shadow:0 -1px 0 rgba(0,0,0,.2);-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,.15),0 1px 1px rgba(0,0,0,.075);box-shadow:inset 0 1px 0 rgba(255,255,255,.15),0 1px 1px rgba(0,0,0,.075)}.btn-danger.active,.btn-danger:active,.btn-default.active,.btn-default:active,.btn-info.active,.btn-info:active,.btn-primary.active,.btn-primary:active,.btn-success.active,.btn-success:active,.btn-warning.active,.btn-warning:active{-webkit-box-shadow:inset 0 3px 5px rgba(0,0,0,.125);box-shadow:inset 0 3px 5px rgba(0,0,0,.125)}.btn-danger.disabled,.btn-danger[disabled],.btn-default.disabled,.btn-default[disabled],.btn-info.disabled,.btn-info[disabled],.btn-primary.disabled,.btn-primary[disabled],.btn-success.disabled,.btn-success[disabled],.btn-warning.disabled,.btn-warning[disabled],fieldset[disabled] .btn-danger,fieldset[disabled] .btn-default,fieldset[disabled] .btn-info,fieldset[disabled] .btn-primary,fieldset[disabled] .btn-success,fieldset[disabled] .btn-warning{-webkit-box-shadow:none;box-shadow:none}.btn-danger .badge,.btn-default .badge,.btn-info .badge,.btn-primary .badge,.btn-success .badge,.btn-warning .badge{text-shadow:none}.btn.active,.btn:active{background-image:none}.btn-default{text-shadow:0 1px 0 #fff;background-image:-webkit-linear-gradient(top,#fff 0,#e0e0e0 100%);background-image:-o-linear-gradient(top,#fff 0,#e0e0e0 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#fff),to(#e0e0e0));background-image:linear-gradient(to bottom,#fff 0,#e0e0e0 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffffffff', endColorstr='#ffe0e0e0', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#dbdbdb;border-color:#ccc}.btn-default:focus,.btn-default:hover{background-color:#e0e0e0;background-position:0 -15px}.btn-default.active,.btn-default:active{background-color:#e0e0e0;border-color:#dbdbdb}.btn-default.disabled,.btn-default.disabled.active,.btn-default.disabled.focus,.btn-default.disabled:active,.btn-default.disabled:focus,.btn-default.disabled:hover,.btn-default[disabled],.btn-default[disabled].active,.btn-default[disabled].focus,.btn-default[disabled]:active,.btn-default[disabled]:focus,.btn-default[disabled]:hover,fieldset[disabled] .btn-default,fieldset[disabled] .btn-default.active,fieldset[disabled] .btn-default.focus,fieldset[disabled] .btn-default:active,fieldset[disabled] .btn-default:focus,fieldset[disabled] .btn-default:hover{background-color:#e0e0e0;background-image:none}.btn-primary{background-image:-webkit-linear-gradient(top,#337ab7 0,#265a88 100%);background-image:-o-linear-gradient(top,#337ab7 0,#265a88 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#265a88));background-image:linear-gradient(to bottom,#337ab7 0,#265a88 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff265a88', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#245580}.btn-primary:focus,.btn-primary:hover{background-color:#265a88;background-position:0 -15px}.btn-primary.active,.btn-primary:active{background-color:#265a88;border-color:#245580}.btn-primary.disabled,.btn-primary.disabled.active,.btn-primary.disabled.focus,.btn-primary.disabled:active,.btn-primary.disabled:focus,.btn-primary.disabled:hover,.btn-primary[disabled],.btn-primary[disabled].active,.btn-primary[disabled].focus,.btn-primary[disabled]:active,.btn-primary[disabled]:focus,.btn-primary[disabled]:hover,fieldset[disabled] .btn-primary,fieldset[disabled] .btn-primary.active,fieldset[disabled] .btn-primary.focus,fieldset[disabled] .btn-primary:active,fieldset[disabled] .btn-primary:focus,fieldset[disabled] .btn-primary:hover{background-color:#265a88;background-image:none}.btn-success{background-image:-webkit-linear-gradient(top,#5cb85c 0,#419641 100%);background-image:-o-linear-gradient(top,#5cb85c 0,#419641 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#5cb85c),to(#419641));background-image:linear-gradient(to bottom,#5cb85c 0,#419641 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff5cb85c', endColorstr='#ff419641', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#3e8f3e}.btn-success:focus,.btn-success:hover{background-color:#419641;background-position:0 -15px}.btn-success.active,.btn-success:active{background-color:#419641;border-color:#3e8f3e}.btn-success.disabled,.btn-success.disabled.active,.btn-success.disabled.focus,.btn-success.disabled:active,.btn-success.disabled:focus,.btn-success.disabled:hover,.btn-success[disabled],.btn-success[disabled].active,.btn-success[disabled].focus,.btn-success[disabled]:active,.btn-success[disabled]:focus,.btn-success[disabled]:hover,fieldset[disabled] .btn-success,fieldset[disabled] .btn-success.active,fieldset[disabled] .btn-success.focus,fieldset[disabled] .btn-success:active,fieldset[disabled] .btn-success:focus,fieldset[disabled] .btn-success:hover{background-color:#419641;background-image:none}.btn-info{background-image:-webkit-linear-gradient(top,#5bc0de 0,#2aabd2 100%);background-image:-o-linear-gradient(top,#5bc0de 0,#2aabd2 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#5bc0de),to(#2aabd2));background-image:linear-gradient(to bottom,#5bc0de 0,#2aabd2 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff5bc0de', endColorstr='#ff2aabd2', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#28a4c9}.btn-info:focus,.btn-info:hover{background-color:#2aabd2;background-position:0 -15px}.btn-info.active,.btn-info:active{background-color:#2aabd2;border-color:#28a4c9}.btn-info.disabled,.btn-info.disabled.active,.btn-info.disabled.focus,.btn-info.disabled:active,.btn-info.disabled:focus,.btn-info.disabled:hover,.btn-info[disabled],.btn-info[disabled].active,.btn-info[disabled].focus,.btn-info[disabled]:active,.btn-info[disabled]:focus,.btn-info[disabled]:hover,fieldset[disabled] .btn-info,fieldset[disabled] .btn-info.active,fieldset[disabled] .btn-info.focus,fieldset[disabled] .btn-info:active,fieldset[disabled] .btn-info:focus,fieldset[disabled] .btn-info:hover{background-color:#2aabd2;background-image:none}.btn-warning{background-image:-webkit-linear-gradient(top,#f0ad4e 0,#eb9316 100%);background-image:-o-linear-gradient(top,#f0ad4e 0,#eb9316 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f0ad4e),to(#eb9316));background-image:linear-gradient(to bottom,#f0ad4e 0,#eb9316 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff0ad4e', endColorstr='#ffeb9316', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#e38d13}.btn-warning:focus,.btn-warning:hover{background-color:#eb9316;background-position:0 -15px}.btn-warning.active,.btn-warning:active{background-color:#eb9316;border-color:#e38d13}.btn-warning.disabled,.btn-warning.disabled.active,.btn-warning.disabled.focus,.btn-warning.disabled:active,.btn-warning.disabled:focus,.btn-warning.disabled:hover,.btn-warning[disabled],.btn-warning[disabled].active,.btn-warning[disabled].focus,.btn-warning[disabled]:active,.btn-warning[disabled]:focus,.btn-warning[disabled]:hover,fieldset[disabled] .btn-warning,fieldset[disabled] .btn-warning.active,fieldset[disabled] .btn-warning.focus,fieldset[disabled] .btn-warning:active,fieldset[disabled] .btn-warning:focus,fieldset[disabled] .btn-warning:hover{background-color:#eb9316;background-image:none}.btn-danger{background-image:-webkit-linear-gradient(top,#d9534f 0,#c12e2a 100%);background-image:-o-linear-gradient(top,#d9534f 0,#c12e2a 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#d9534f),to(#c12e2a));background-image:linear-gradient(to bottom,#d9534f 0,#c12e2a 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffd9534f', endColorstr='#ffc12e2a', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-color:#b92c28}.btn-danger:focus,.btn-danger:hover{background-color:#c12e2a;background-position:0 -15px}.btn-danger.active,.btn-danger:active{background-color:#c12e2a;border-color:#b92c28}.btn-danger.disabled,.btn-danger.disabled.active,.btn-danger.disabled.focus,.btn-danger.disabled:active,.btn-danger.disabled:focus,.btn-danger.disabled:hover,.btn-danger[disabled],.btn-danger[disabled].active,.btn-danger[disabled].focus,.btn-danger[disabled]:active,.btn-danger[disabled]:focus,.btn-danger[disabled]:hover,fieldset[disabled] .btn-danger,fieldset[disabled] .btn-danger.active,fieldset[disabled] .btn-danger.focus,fieldset[disabled] .btn-danger:active,fieldset[disabled] .btn-danger:focus,fieldset[disabled] .btn-danger:hover{background-color:#c12e2a;background-image:none}.img-thumbnail,.thumbnail{-webkit-box-shadow:0 1px 2px rgba(0,0,0,.075);box-shadow:0 1px 2px rgba(0,0,0,.075)}.dropdown-menu>li>a:focus,.dropdown-menu>li>a:hover{background-color:#e8e8e8;background-image:-webkit-linear-gradient(top,#f5f5f5 0,#e8e8e8 100%);background-image:-o-linear-gradient(top,#f5f5f5 0,#e8e8e8 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f5f5f5),to(#e8e8e8));background-image:linear-gradient(to bottom,#f5f5f5 0,#e8e8e8 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff5f5f5', endColorstr='#ffe8e8e8', GradientType=0);background-repeat:repeat-x}.dropdown-menu>.active>a,.dropdown-menu>.active>a:focus,.dropdown-menu>.active>a:hover{background-color:#2e6da4;background-image:-webkit-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-o-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#2e6da4));background-image:linear-gradient(to bottom,#337ab7 0,#2e6da4 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff2e6da4', GradientType=0);background-repeat:repeat-x}.navbar-default{background-image:-webkit-linear-gradient(top,#fff 0,#f8f8f8 100%);background-image:-o-linear-gradient(top,#fff 0,#f8f8f8 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#fff),to(#f8f8f8));background-image:linear-gradient(to bottom,#fff 0,#f8f8f8 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffffffff', endColorstr='#fff8f8f8', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-radius:4px;-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,.15),0 1px 5px rgba(0,0,0,.075);box-shadow:inset 0 1px 0 rgba(255,255,255,.15),0 1px 5px rgba(0,0,0,.075)}.navbar-default .navbar-nav>.active>a,.navbar-default .navbar-nav>.open>a{background-image:-webkit-linear-gradient(top,#dbdbdb 0,#e2e2e2 100%);background-image:-o-linear-gradient(top,#dbdbdb 0,#e2e2e2 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#dbdbdb),to(#e2e2e2));background-image:linear-gradient(to bottom,#dbdbdb 0,#e2e2e2 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffdbdbdb', endColorstr='#ffe2e2e2', GradientType=0);background-repeat:repeat-x;-webkit-box-shadow:inset 0 3px 9px rgba(0,0,0,.075);box-shadow:inset 0 3px 9px rgba(0,0,0,.075)}.navbar-brand,.navbar-nav>li>a{text-shadow:0 1px 0 rgba(255,255,255,.25)}.navbar-inverse{background-image:-webkit-linear-gradient(top,#3c3c3c 0,#222 100%);background-image:-o-linear-gradient(top,#3c3c3c 0,#222 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#3c3c3c),to(#222));background-image:linear-gradient(to bottom,#3c3c3c 0,#222 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff3c3c3c', endColorstr='#ff222222', GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);background-repeat:repeat-x;border-radius:4px}.navbar-inverse .navbar-nav>.active>a,.navbar-inverse .navbar-nav>.open>a{background-image:-webkit-linear-gradient(top,#080808 0,#0f0f0f 100%);background-image:-o-linear-gradient(top,#080808 0,#0f0f0f 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#080808),to(#0f0f0f));background-image:linear-gradient(to bottom,#080808 0,#0f0f0f 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff080808', endColorstr='#ff0f0f0f', GradientType=0);background-repeat:repeat-x;-webkit-box-shadow:inset 0 3px 9px rgba(0,0,0,.25);box-shadow:inset 0 3px 9px rgba(0,0,0,.25)}.navbar-inverse .navbar-brand,.navbar-inverse .navbar-nav>li>a{text-shadow:0 -1px 0 rgba(0,0,0,.25)}.navbar-fixed-bottom,.navbar-fixed-top,.navbar-static-top{border-radius:0}@media (max-width:767px){.navbar .navbar-nav .open .dropdown-menu>.active>a,.navbar .navbar-nav .open .dropdown-menu>.active>a:focus,.navbar .navbar-nav .open .dropdown-menu>.active>a:hover{color:#fff;background-image:-webkit-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-o-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#2e6da4));background-image:linear-gradient(to bottom,#337ab7 0,#2e6da4 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff2e6da4', GradientType=0);background-repeat:repeat-x}}.alert{text-shadow:0 1px 0 rgba(255,255,255,.2);-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,.25),0 1px 2px rgba(0,0,0,.05);box-shadow:inset 0 1px 0 rgba(255,255,255,.25),0 1px 2px rgba(0,0,0,.05)}.alert-success{background-image:-webkit-linear-gradient(top,#dff0d8 0,#c8e5bc 100%);background-image:-o-linear-gradient(top,#dff0d8 0,#c8e5bc 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#dff0d8),to(#c8e5bc));background-image:linear-gradient(to bottom,#dff0d8 0,#c8e5bc 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffdff0d8', endColorstr='#ffc8e5bc', GradientType=0);background-repeat:repeat-x;border-color:#b2dba1}.alert-info{background-image:-webkit-linear-gradient(top,#d9edf7 0,#b9def0 100%);background-image:-o-linear-gradient(top,#d9edf7 0,#b9def0 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#d9edf7),to(#b9def0));background-image:linear-gradient(to bottom,#d9edf7 0,#b9def0 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffd9edf7', endColorstr='#ffb9def0', GradientType=0);background-repeat:repeat-x;border-color:#9acfea}.alert-warning{background-image:-webkit-linear-gradient(top,#fcf8e3 0,#f8efc0 100%);background-image:-o-linear-gradient(top,#fcf8e3 0,#f8efc0 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#fcf8e3),to(#f8efc0));background-image:linear-gradient(to bottom,#fcf8e3 0,#f8efc0 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fffcf8e3', endColorstr='#fff8efc0', GradientType=0);background-repeat:repeat-x;border-color:#f5e79e}.alert-danger{background-image:-webkit-linear-gradient(top,#f2dede 0,#e7c3c3 100%);background-image:-o-linear-gradient(top,#f2dede 0,#e7c3c3 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f2dede),to(#e7c3c3));background-image:linear-gradient(to bottom,#f2dede 0,#e7c3c3 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff2dede', endColorstr='#ffe7c3c3', GradientType=0);background-repeat:repeat-x;border-color:#dca7a7}.progress{background-image:-webkit-linear-gradient(top,#ebebeb 0,#f5f5f5 100%);background-image:-o-linear-gradient(top,#ebebeb 0,#f5f5f5 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#ebebeb),to(#f5f5f5));background-image:linear-gradient(to bottom,#ebebeb 0,#f5f5f5 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffebebeb', endColorstr='#fff5f5f5', GradientType=0);background-repeat:repeat-x}.progress-bar{background-image:-webkit-linear-gradient(top,#337ab7 0,#286090 100%);background-image:-o-linear-gradient(top,#337ab7 0,#286090 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#286090));background-image:linear-gradient(to bottom,#337ab7 0,#286090 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff286090', GradientType=0);background-repeat:repeat-x}.progress-bar-success{background-image:-webkit-linear-gradient(top,#5cb85c 0,#449d44 100%);background-image:-o-linear-gradient(top,#5cb85c 0,#449d44 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#5cb85c),to(#449d44));background-image:linear-gradient(to bottom,#5cb85c 0,#449d44 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff5cb85c', endColorstr='#ff449d44', GradientType=0);background-repeat:repeat-x}.progress-bar-info{background-image:-webkit-linear-gradient(top,#5bc0de 0,#31b0d5 100%);background-image:-o-linear-gradient(top,#5bc0de 0,#31b0d5 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#5bc0de),to(#31b0d5));background-image:linear-gradient(to bottom,#5bc0de 0,#31b0d5 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff5bc0de', endColorstr='#ff31b0d5', GradientType=0);background-repeat:repeat-x}.progress-bar-warning{background-image:-webkit-linear-gradient(top,#f0ad4e 0,#ec971f 100%);background-image:-o-linear-gradient(top,#f0ad4e 0,#ec971f 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f0ad4e),to(#ec971f));background-image:linear-gradient(to bottom,#f0ad4e 0,#ec971f 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff0ad4e', endColorstr='#ffec971f', GradientType=0);background-repeat:repeat-x}.progress-bar-danger{background-image:-webkit-linear-gradient(top,#d9534f 0,#c9302c 100%);background-image:-o-linear-gradient(top,#d9534f 0,#c9302c 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#d9534f),to(#c9302c));background-image:linear-gradient(to bottom,#d9534f 0,#c9302c 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffd9534f', endColorstr='#ffc9302c', GradientType=0);background-repeat:repeat-x}.progress-bar-striped{background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.15) 50%,rgba(255,255,255,.15) 75%,transparent 75%,transparent)}.list-group{border-radius:4px;-webkit-box-shadow:0 1px 2px rgba(0,0,0,.075);box-shadow:0 1px 2px rgba(0,0,0,.075)}.list-group-item.active,.list-group-item.active:focus,.list-group-item.active:hover{text-shadow:0 -1px 0 #286090;background-image:-webkit-linear-gradient(top,#337ab7 0,#2b669a 100%);background-image:-o-linear-gradient(top,#337ab7 0,#2b669a 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#2b669a));background-image:linear-gradient(to bottom,#337ab7 0,#2b669a 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff2b669a', GradientType=0);background-repeat:repeat-x;border-color:#2b669a}.list-group-item.active .badge,.list-group-item.active:focus .badge,.list-group-item.active:hover .badge{text-shadow:none}.panel{-webkit-box-shadow:0 1px 2px rgba(0,0,0,.05);box-shadow:0 1px 2px rgba(0,0,0,.05)}.panel-default>.panel-heading{background-image:-webkit-linear-gradient(top,#f5f5f5 0,#e8e8e8 100%);background-image:-o-linear-gradient(top,#f5f5f5 0,#e8e8e8 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f5f5f5),to(#e8e8e8));background-image:linear-gradient(to bottom,#f5f5f5 0,#e8e8e8 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff5f5f5', endColorstr='#ffe8e8e8', GradientType=0);background-repeat:repeat-x}.panel-primary>.panel-heading{background-image:-webkit-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-o-linear-gradient(top,#337ab7 0,#2e6da4 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#337ab7),to(#2e6da4));background-image:linear-gradient(to bottom,#337ab7 0,#2e6da4 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ff337ab7', endColorstr='#ff2e6da4', GradientType=0);background-repeat:repeat-x}.panel-success>.panel-heading{background-image:-webkit-linear-gradient(top,#dff0d8 0,#d0e9c6 100%);background-image:-o-linear-gradient(top,#dff0d8 0,#d0e9c6 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#dff0d8),to(#d0e9c6));background-image:linear-gradient(to bottom,#dff0d8 0,#d0e9c6 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffdff0d8', endColorstr='#ffd0e9c6', GradientType=0);background-repeat:repeat-x}.panel-info>.panel-heading{background-image:-webkit-linear-gradient(top,#d9edf7 0,#c4e3f3 100%);background-image:-o-linear-gradient(top,#d9edf7 0,#c4e3f3 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#d9edf7),to(#c4e3f3));background-image:linear-gradient(to bottom,#d9edf7 0,#c4e3f3 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffd9edf7', endColorstr='#ffc4e3f3', GradientType=0);background-repeat:repeat-x}.panel-warning>.panel-heading{background-image:-webkit-linear-gradient(top,#fcf8e3 0,#faf2cc 100%);background-image:-o-linear-gradient(top,#fcf8e3 0,#faf2cc 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#fcf8e3),to(#faf2cc));background-image:linear-gradient(to bottom,#fcf8e3 0,#faf2cc 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fffcf8e3', endColorstr='#fffaf2cc', GradientType=0);background-repeat:repeat-x}.panel-danger>.panel-heading{background-image:-webkit-linear-gradient(top,#f2dede 0,#ebcccc 100%);background-image:-o-linear-gradient(top,#f2dede 0,#ebcccc 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#f2dede),to(#ebcccc));background-image:linear-gradient(to bottom,#f2dede 0,#ebcccc 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#fff2dede', endColorstr='#ffebcccc', GradientType=0);background-repeat:repeat-x}.well{background-image:-webkit-linear-gradient(top,#e8e8e8 0,#f5f5f5 100%);background-image:-o-linear-gradient(top,#e8e8e8 0,#f5f5f5 100%);background-image:-webkit-gradient(linear,left top,left bottom,from(#e8e8e8),to(#f5f5f5));background-image:linear-gradient(to bottom,#e8e8e8 0,#f5f5f5 100%);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffe8e8e8', endColorstr='#fff5f5f5', GradientType=0);background-repeat:repeat-x;border-color:#dcdcdc;-webkit-box-shadow:inset 0 1px 3px rgba(0,0,0,.05),0 1px 0 rgba(255,255,255,.1);box-shadow:inset 0 1px 3px rgba(0,0,0,.05),0 1px 0 rgba(255,255,255,.1)}
/*# sourceMappingURL=bootstrap-theme.min.css.map */
(function(g,d){var f={extend:function(a,c){for(var h in c)-1!=="browser cpu device engine os".indexOf(h)&&0===c[h].length%2&&(a[h]=c[h].concat(a[h]));return a},has:function(a,c){return"string"===typeof a?-1!==c.toLowerCase().indexOf(a.toLowerCase()):!1},lowerize:function(a){return a.toLowerCase()},major:function(a){return"string"===typeof a?a.split(".")[0]:d}},n=function(){for(var a,c=0,h,b,e,k,g,f,p=arguments;c<p.length&&!g;){var q=p[c],n=p[c+1];if("undefined"===typeof a)for(e in a={},n)n.hasOwnProperty(e)&&
(k=n[e],"object"===typeof k?a[k[0]]=d:a[k]=d);for(h=b=0;h<q.length&&!g;)if(g=q[h++].exec(this.getUA()))for(e=0;e<n.length;e++)f=g[++b],k=n[e],"object"===typeof k&&0<k.length?2==k.length?a[k[0]]="function"==typeof k[1]?k[1].call(this,f):k[1]:3==k.length?a[k[0]]="function"!==typeof k[1]||k[1].exec&&k[1].test?f?f.replace(k[1],k[2]):d:f?k[1].call(this,f,k[2]):d:4==k.length&&(a[k[0]]=f?k[3].call(this,f.replace(k[1],k[2])):d):a[k]=f?f:d;c+=2}return a},b=function(a,c){for(var h in c)if("object"===typeof c[h]&&
0<c[h].length)for(var b=0;b<c[h].length;b++){if(f.has(c[h][b],a))return"?"===h?d:h}else if(f.has(c[h],a))return"?"===h?d:h;return a},e={ME:"4.90","NT 3.11":"NT3.51","NT 4.0":"NT4.0",2E3:"NT 5.0",XP:["NT 5.1","NT 5.2"],Vista:"NT 6.0",7:"NT 6.1",8:"NT 6.2","8.1":"NT 6.3",10:["NT 6.4","NT 10.0"],RT:"ARM"},p={browser:[[/(opera\smini)\/([\w\.-]+)/i,/(opera\s[mobiletab]+).+version\/([\w\.-]+)/i,/(opera).+version\/([\w\.]+)/i,/(opera)[\/\s]+([\w\.]+)/i],["name","version"],[/\s(opr)\/([\w\.]+)/i],[["name",
"Opera"],"version"],[/(kindle)\/([\w\.]+)/i,/(lunascape|maxthon|netfront|jasmine|blazer)[\/\s]?([\w\.]+)*/i,/(avant\s|iemobile|slim|baidu)(?:browser)?[\/\s]?([\w\.]*)/i,/(?:ms|\()(ie)\s([\w\.]+)/i,/(rekonq)\/([\w\.]+)*/i,/(chromium|flock|rockmelt|midori|epiphany|silk|skyfire|ovibrowser|bolt|iron|vivaldi|iridium|phantomjs)\/([\w\.-]+)/i],["name","version"],[/(trident).+rv[:\s]([\w\.]+).+like\sgecko/i],[["name","IE"],"version"],[/(edge)\/((\d+)?[\w\.]+)/i],["name","version"],[/(yabrowser)\/([\w\.]+)/i],
[["name","Yandex"],"version"],[/(comodo_dragon)\/([\w\.]+)/i],[["name",/_/g," "],"version"],[/(chrome|omniweb|arora|[tizenoka]{5}\s?browser)\/v?([\w\.]+)/i,/(qqbrowser)[\/\s]?([\w\.]+)/i],["name","version"],[/(uc\s?browser)[\/\s]?([\w\.]+)/i,/ucweb.+(ucbrowser)[\/\s]?([\w\.]+)/i,/JUC.+(ucweb)[\/\s]?([\w\.]+)/i],[["name","UCBrowser"],"version"],[/(dolfin)\/([\w\.]+)/i],[["name","Dolphin"],"version"],[/((?:android.+)crmo|crios)\/([\w\.]+)/i],[["name","Chrome"],"version"],[/XiaoMi\/MiuiBrowser\/([\w\.]+)/i],
["version",["name","MIUI Browser"]],[/android.+version\/([\w\.]+)\s+(?:mobile\s?safari|safari)/i],["version",["name","Android Browser"]],[/FBAV\/([\w\.]+);/i],["version",["name","Facebook"]],[/fxios\/([\w\.-]+)/i],["version",["name","Firefox"]],[/version\/([\w\.]+).+?mobile\/\w+\s(safari)/i],["version",["name","Mobile Safari"]],[/version\/([\w\.]+).+?(mobile\s?safari|safari)/i],["version","name"],[/webkit.+?(mobile\s?safari|safari)(\/[\w\.]+)/i],["name",["version",b,{"1.0":"/8","1.2":"/1","1.3":"/3",
"2.0":"/412","2.0.2":"/416","2.0.3":"/417","2.0.4":"/419","?":"/"}]],[/(konqueror)\/([\w\.]+)/i,/(webkit|khtml)\/([\w\.]+)/i],["name","version"],[/(navigator|netscape)\/([\w\.-]+)/i],[["name","Netscape"],"version"],[/(swiftfox)/i,/(icedragon|iceweasel|camino|chimera|fennec|maemo\sbrowser|minimo|conkeror)[\/\s]?([\w\.\+]+)/i,/(firefox|seamonkey|k-meleon|icecat|iceape|firebird|phoenix)\/([\w\.-]+)/i,/(mozilla)\/([\w\.]+).+rv\:.+gecko\/\d+/i,/(polaris|lynx|dillo|icab|doris|amaya|w3m|netsurf|sleipnir)[\/\s]?([\w\.]+)/i,
/(links)\s\(([\w\.]+)/i,/(gobrowser)\/?([\w\.]+)*/i,/(ice\s?browser)\/v?([\w\._]+)/i,/(mosaic)[\/\s]([\w\.]+)/i],["name","version"]],cpu:[[/(?:(amd|x(?:(?:86|64)[_-])?|wow|win)64)[;\)]/i],[["architecture","amd64"]],[/(ia32(?=;))/i],[["architecture",f.lowerize]],[/((?:i[346]|x)86)[;\)]/i],[["architecture","ia32"]],[/windows\s(ce|mobile);\sppc;/i],[["architecture","arm"]],[/((?:ppc|powerpc)(?:64)?)(?:\smac|;|\))/i],[["architecture",/ower/,"",f.lowerize]],[/(sun4\w)[;\)]/i],[["architecture","sparc"]],
[/((?:avr32|ia64(?=;))|68k(?=\))|arm(?:64|(?=v\d+;))|(?=atmel\s)avr|(?:irix|mips|sparc)(?:64)?(?=;)|pa-risc)/i],[["architecture",f.lowerize]]],device:[[/\((ipad|playbook);[\w\s\);-]+(rim|apple)/i],["model","vendor",["type","tablet"]],[/applecoremedia\/[\w\.]+ \((ipad)/],["model",["vendor","Apple"],["type","tablet"]],[/(apple\s{0,1}tv)/i],[["model","Apple TV"],["vendor","Apple"]],[/(archos)\s(gamepad2?)/i,/(hp).+(touchpad)/i,/(kindle)\/([\w\.]+)/i,/\s(nook)[\w\s]+build\/(\w+)/i,/(dell)\s(strea[kpr\s\d]*[\dko])/i],
["vendor","model",["type","tablet"]],[/(kf[A-z]+)\sbuild\/[\w\.]+.*silk\//i],["model",["vendor","Amazon"],["type","tablet"]],[/(sd|kf)[0349hijorstuw]+\sbuild\/[\w\.]+.*silk\//i],[["model",b,{"Fire Phone":["SD","KF"]}],["vendor","Amazon"],["type","mobile"]],[/\((ip[honed|\s\w*]+);.+(apple)/i],["model","vendor",["type","mobile"]],[/\((ip[honed|\s\w*]+);/i],["model",["vendor","Apple"],["type","mobile"]],[/(blackberry)[\s-]?(\w+)/i,/(blackberry|benq|palm(?=\-)|sonyericsson|acer|asus|dell|huawei|meizu|motorola|polytron)[\s_-]?([\w-]+)*/i,
/(hp)\s([\w\s]+\w)/i,/(asus)-?(\w+)/i],["vendor","model",["type","mobile"]],[/\(bb10;\s(\w+)/i],["model",["vendor","BlackBerry"],["type","mobile"]],[/android.+(transfo[prime\s]{4,10}\s\w+|eeepc|slider\s\w+|nexus 7)/i],["model",["vendor","Asus"],["type","tablet"]],[/(sony)\s(tablet\s[ps])\sbuild\//i,/(sony)?(?:sgp.+)\sbuild\//i],[["vendor","Sony"],["model","Xperia Tablet"],["type","tablet"]],[/(?:sony)?(?:(?:(?:c|d)\d{4})|(?:so[-l].+))\sbuild\//i],[["vendor","Sony"],["model","Xperia Phone"],["type",
"mobile"]],[/\s(ouya)\s/i,/(nintendo)\s([wids3u]+)/i],["vendor","model",["type","console"]],[/android.+;\s(shield)\sbuild/i],["model",["vendor","Nvidia"],["type","console"]],[/(playstation\s[34portablevi]+)/i],["model",["vendor","Sony"],["type","console"]],[/(sprint\s(\w+))/i],[["vendor",b,{HTC:"APA",Sprint:"Sprint"}],["model",b,{"Evo Shift 4G":"7373KT"}],["type","mobile"]],[/(lenovo)\s?(S(?:5000|6000)+(?:[-][\w+]))/i],["vendor","model",["type","tablet"]],[/(htc)[;_\s-]+([\w\s]+(?=\))|\w+)*/i,/(zte)-(\w+)*/i,
/(alcatel|geeksphone|huawei|lenovo|nexian|panasonic|(?=;\s)sony)[_\s-]?([\w-]+)*/i],["vendor",["model",/_/g," "],["type","mobile"]],[/(nexus\s9)/i],["model",["vendor","HTC"],["type","tablet"]],[/[\s\(;](xbox(?:\sone)?)[\s\);]/i],["model",["vendor","Microsoft"],["type","console"]],[/(kin\.[onetw]{3})/i],[["model",/\./g," "],["vendor","Microsoft"],["type","mobile"]],[/\s(milestone|droid(?:[2-4x]|\s(?:bionic|x2|pro|razr))?(:?\s4g)?)[\w\s]+build\//i,/mot[\s-]?(\w+)*/i,/(XT\d{3,4}) build\//i,/(nexus\s[6])/i],
["model",["vendor","Motorola"],["type","mobile"]],[/android.+\s(mz60\d|xoom[\s2]{0,2})\sbuild\//i],["model",["vendor","Motorola"],["type","tablet"]],[/android.+((sch-i[89]0\d|shw-m380s|gt-p\d{4}|gt-n8000|sgh-t8[56]9|nexus 10))/i,/((SM-T\w+))/i],[["vendor","Samsung"],"model",["type","tablet"]],[/((s[cgp]h-\w+|gt-\w+|galaxy\snexus|sm-n900))/i,/(sam[sung]*)[\s-]*(\w+-?[\w-]*)*/i,/sec-((sgh\w+))/i],[["vendor","Samsung"],"model",["type","mobile"]],[/(samsung);smarttv/i],["vendor","model",["type","smarttv"]],
[/\(dtv[\);].+(aquos)/i],["model",["vendor","Sharp"],["type","smarttv"]],[/sie-(\w+)*/i],["model",["vendor","Siemens"],["type","mobile"]],[/(maemo|nokia).*(n900|lumia\s\d+)/i,/(nokia)[\s_-]?([\w-]+)*/i],[["vendor","Nokia"],"model",["type","mobile"]],[/android\s3\.[\s\w;-]{10}(a\d{3})/i],["model",["vendor","Acer"],["type","tablet"]],[/android\s3\.[\s\w;-]{10}(lg?)-([06cv9]{3,4})/i],[["vendor","LG"],"model",["type","tablet"]],[/(lg) netcast\.tv/i],["vendor","model",["type","smarttv"]],[/(nexus\s[45])/i,
/lg[e;\s\/-]+(\w+)*/i],["model",["vendor","LG"],["type","mobile"]],[/android.+(ideatab[a-z0-9\-\s]+)/i],["model",["vendor","Lenovo"],["type","tablet"]],[/linux;.+((jolla));/i],["vendor","model",["type","mobile"]],[/((pebble))app\/[\d\.]+\s/i],["vendor","model",["type","wearable"]],[/android.+;\s(glass)\s\d/i],["model",["vendor","Google"],["type","wearable"]],[/android.+(\w+)\s+build\/hm\1/i,/android.+(hm[\s\-_]*note?[\s_]*(?:\d\w)?)\s+build/i,/android.+(mi[\s\-_]*(?:one|one[\s_]plus)?[\s_]*(?:\d\w)?)\s+build/i],
[["model",/_/g," "],["vendor","Xiaomi"],["type","mobile"]],[/\s(tablet)[;\/\s]/i,/\s(mobile)[;\/\s]/i],[["type",f.lowerize],"vendor","model"]],engine:[[/windows.+\sedge\/([\w\.]+)/i],["version",["name","EdgeHTML"]],[/(presto)\/([\w\.]+)/i,/(webkit|trident|netfront|netsurf|amaya|lynx|w3m)\/([\w\.]+)/i,/(khtml|tasman|links)[\/\s]\(?([\w\.]+)/i,/(icab)[\/\s]([23]\.[\d\.]+)/i],["name","version"],[/rv\:([\w\.]+).*(gecko)/i],["version","name"]],os:[[/microsoft\s(windows)\s(vista|xp)/i],["name","version"],
[/(windows)\snt\s6\.2;\s(arm)/i,/(windows\sphone(?:\sos)*|windows\smobile|windows)[\s\/]?([ntce\d\.\s]+\w)/i],["name",["version",b,e]],[/(win(?=3|9|n)|win\s9x\s)([nt\d\.]+)/i],[["name","Windows"],["version",b,e]],[/\((bb)(10);/i],[["name","BlackBerry"],"version"],[/(blackberry)\w*\/?([\w\.]+)*/i,/(tizen)[\/\s]([\w\.]+)/i,/(android|webos|palm\sos|qnx|bada|rim\stablet\sos|meego|contiki)[\/\s-]?([\w\.]+)*/i,/linux;.+(sailfish);/i],["name","version"],[/(symbian\s?os|symbos|s60(?=;))[\/\s-]?([\w\.]+)*/i],
[["name","Symbian"],"version"],[/\((series40);/i],["name"],[/mozilla.+\(mobile;.+gecko.+firefox/i],[["name","Firefox OS"],"version"],[/(nintendo|playstation)\s([wids34portablevu]+)/i,/(mint)[\/\s\(]?(\w+)*/i,/(mageia|vectorlinux)[;\s]/i,/(joli|[kxln]?ubuntu|debian|[open]*suse|gentoo|(?=\s)arch|slackware|fedora|mandriva|centos|pclinuxos|redhat|zenwalk|linpus)[\/\s-]?([\w\.-]+)*/i,/(hurd|linux)\s?([\w\.]+)*/i,/(gnu)\s?([\w\.]+)*/i],["name","version"],[/(cros)\s[\w]+\s([\w\.]+\w)/i],[["name","Chromium OS"],
"version"],[/(sunos)\s?([\w\.]+\d)*/i],[["name","Solaris"],"version"],[/\s([frentopc-]{0,4}bsd|dragonfly)\s?([\w\.]+)*/i],["name","version"],[/(ip[honead]+)(?:.*os\s([\w]+)*\slike\smac|;\sopera)/i],[["name","iOS"],["version",/_/g,"."]],[/(mac\sos\sx)\s?([\w\s\.]+\w)*/i,/(macintosh|mac(?=_powerpc)\s)/i],[["name","Mac OS"],["version",/_/g,"."]],[/((?:open)?solaris)[\/\s-]?([\w\.]+)*/i,/(haiku)\s(\w+)/i,/(aix)\s((\d)(?=\.|\)|\s)[\w\.]*)*/i,/(plan\s9|minix|beos|os\/2|amigaos|morphos|risc\sos|openvms)/i,
/(unix)\s?([\w\.]+)*/i],["name","version"]]},q=function(a,c){if(!(this instanceof q))return(new q(a,c)).getResult();var h=a||(g&&g.navigator&&g.navigator.userAgent?g.navigator.userAgent:""),b=c?f.extend(p,c):p;this.getBrowser=function(){var a=n.apply(this,b.browser);a.major=f.major(a.version);return a};this.getCPU=function(){return n.apply(this,b.cpu)};this.getDevice=function(){return n.apply(this,b.device)};this.getEngine=function(){return n.apply(this,b.engine)};this.getOS=function(){return n.apply(this,
b.os)};this.getResult=function(){return{ua:this.getUA(),browser:this.getBrowser(),engine:this.getEngine(),os:this.getOS(),device:this.getDevice(),cpu:this.getCPU()}};this.getUA=function(){return h};this.setUA=function(a){h=a;return this};this.setUA(h);return this};q.VERSION="0.7.10";q.BROWSER={NAME:"name",MAJOR:"major",VERSION:"version"};q.CPU={ARCHITECTURE:"architecture"};q.DEVICE={MODEL:"model",VENDOR:"vendor",TYPE:"type",CONSOLE:"console",MOBILE:"mobile",SMARTTV:"smarttv",TABLET:"tablet",WEARABLE:"wearable",
EMBEDDED:"embedded"};q.ENGINE={NAME:"name",VERSION:"version"};q.OS={NAME:"name",VERSION:"version"};"undefined"!==typeof exports?("undefined"!==typeof module&&module.exports&&(exports=module.exports=q),exports.UAParser=q):"function"===typeof define&&define.amd?define(function(){return q}):g.UAParser=q;var r=g.jQuery||g.Zepto;if("undefined"!==typeof r){var v=new q;r.ua=v.getResult();r.ua.get=function(){return v.getUA()};r.ua.set=function(a){v.setUA(a);a=v.getResult();for(var c in a)r.ua[c]=a[c]}}})("object"===
typeof window?window:this);var Detector=function(){var g=["monospace","sans-serif","serif"],d=document.getElementsByTagName("body")[0],f=document.createElement("span");f.style.fontSize="72px";f.innerHTML="mmmmmmmmmmlli";var n={},b={},e;for(e in g)f.style.fontFamily=g[e],d.appendChild(f),n[g[e]]=f.offsetWidth,b[g[e]]=f.offsetHeight,d.removeChild(f);this.detect=function(e){var q=!1,r;for(r in g){f.style.fontFamily=e+","+g[r];d.appendChild(f);var v=f.offsetWidth!=n[g[r]]||f.offsetHeight!=b[g[r]];d.removeChild(f);q=q||v}return q}};var swfobject=function(){function g(){if(!C){try{var a=m.getElementsByTagName("body")[0].appendChild(m.createElement("span"));a.parentNode.removeChild(a)}catch(c){return}C=!0;for(var a=H.length,h=0;h<a;h++)H[h]()}}function d(a){C?a():H[H.length]=a}function f(a){if(typeof w.addEventListener!=u)w.addEventListener("load",a,!1);else if(typeof m.addEventListener!=u)m.addEventListener("load",a,!1);else if(typeof w.attachEvent!=u)t(w,"onload",a);else if("function"==typeof w.onload){var c=w.onload;w.onload=
function(){c();a()}}else w.onload=a}function n(){var a=m.getElementsByTagName("body")[0],c=m.createElement(x);c.setAttribute("type",G);var h=a.appendChild(c);if(h){var e=0;(function(){if(typeof h.GetVariable!=u){var d=h.GetVariable("$version");d&&(d=d.split(" ")[1].split(","),l.pv=[parseInt(d[0],10),parseInt(d[1],10),parseInt(d[2],10)])}else if(10>e){e++;setTimeout(arguments.callee,10);return}a.removeChild(c);h=null;b()})()}else b()}function b(){var a=z.length;if(0<a)for(var c=0;c<a;c++){var b=z[c].id,
d=z[c].callbackFn,f={success:!1,id:b};if(0<l.pv[0]){var k=h(b);if(k)if(!D(z[c].swfVersion)||l.wk&&312>l.wk)if(z[c].expressInstall&&p()){f={};f.data=z[c].expressInstall;f.width=k.getAttribute("width")||"0";f.height=k.getAttribute("height")||"0";k.getAttribute("class")&&(f.styleclass=k.getAttribute("class"));k.getAttribute("align")&&(f.align=k.getAttribute("align"));for(var g={},k=k.getElementsByTagName("param"),m=k.length,t=0;t<m;t++)"movie"!=k[t].getAttribute("name").toLowerCase()&&(g[k[t].getAttribute("name")]=
k[t].getAttribute("value"));q(f,g,b,d)}else r(k),d&&d(f);else B(b,!0),d&&(f.success=!0,f.ref=e(b),d(f))}else B(b,!0),d&&((b=e(b))&&typeof b.SetVariable!=u&&(f.success=!0,f.ref=b),d(f))}}function e(a){var c=null;(a=h(a))&&"OBJECT"==a.nodeName&&(typeof a.SetVariable!=u?c=a:(a=a.getElementsByTagName(x)[0])&&(c=a));return c}function p(){return!I&&D("6.0.65")&&(l.win||l.mac)&&!(l.wk&&312>l.wk)}function q(c,b,e,d){I=!0;L=d||null;O={success:!1,id:e};var f=h(e);if(f){"OBJECT"==f.nodeName?(F=v(f),J=null):
(F=f,J=e);c.id=P;if(typeof c.width==u||!/%$/.test(c.width)&&310>parseInt(c.width,10))c.width="310";if(typeof c.height==u||!/%$/.test(c.height)&&137>parseInt(c.height,10))c.height="137";m.title=m.title.slice(0,47)+" - Flash Player Installation";d=l.ie&&l.win?"ActiveX":"PlugIn";d="MMredirectURL="+w.location.toString().replace(/&/g,"%26")+"&MMplayerType="+d+"&MMdoctitle="+m.title;b.flashvars=typeof b.flashvars!=u?b.flashvars+("&"+d):d;l.ie&&l.win&&4!=f.readyState&&(d=m.createElement("div"),e+="SWFObjectNew",
d.setAttribute("id",e),f.parentNode.insertBefore(d,f),f.style.display="none",function(){4==f.readyState?f.parentNode.removeChild(f):setTimeout(arguments.callee,10)}());a(c,b,e)}}function r(a){if(l.ie&&l.win&&4!=a.readyState){var c=m.createElement("div");a.parentNode.insertBefore(c,a);c.parentNode.replaceChild(v(a),c);a.style.display="none";(function(){4==a.readyState?a.parentNode.removeChild(a):setTimeout(arguments.callee,10)})()}else a.parentNode.replaceChild(v(a),a)}function v(a){var c=m.createElement("div");
if(l.win&&l.ie)c.innerHTML=a.innerHTML;else if(a=a.getElementsByTagName(x)[0])if(a=a.childNodes)for(var b=a.length,h=0;h<b;h++)1==a[h].nodeType&&"PARAM"==a[h].nodeName||8==a[h].nodeType||c.appendChild(a[h].cloneNode(!0));return c}function a(a,c,b){var e,d=h(b);if(l.wk&&312>l.wk)return e;if(d)if(typeof a.id==u&&(a.id=b),l.ie&&l.win){var f="",k;for(k in a)a[k]!=Object.prototype[k]&&("data"==k.toLowerCase()?c.movie=a[k]:"styleclass"==k.toLowerCase()?f+=' class="'+a[k]+'"':"classid"!=k.toLowerCase()&&
(f+=" "+k+'="'+a[k]+'"'));k="";for(var g in c)c[g]!=Object.prototype[g]&&(k+='<param name="'+g+'" value="'+c[g]+'" />');d.outerHTML='<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"'+f+">"+k+"</object>";K[K.length]=a.id;e=h(a.id)}else{g=m.createElement(x);g.setAttribute("type",G);for(var t in a)a[t]!=Object.prototype[t]&&("styleclass"==t.toLowerCase()?g.setAttribute("class",a[t]):"classid"!=t.toLowerCase()&&g.setAttribute(t,a[t]));for(f in c)c[f]!=Object.prototype[f]&&"movie"!=f.toLowerCase()&&
(a=g,k=f,t=c[f],b=m.createElement("param"),b.setAttribute("name",k),b.setAttribute("value",t),a.appendChild(b));d.parentNode.replaceChild(g,d);e=g}return e}function c(a){var c=h(a);c&&"OBJECT"==c.nodeName&&(l.ie&&l.win?(c.style.display="none",function(){if(4==c.readyState){var b=h(a);if(b){for(var e in b)"function"==typeof b[e]&&(b[e]=null);b.parentNode.removeChild(b)}}else setTimeout(arguments.callee,10)}()):c.parentNode.removeChild(c))}function h(a){var c=null;try{c=m.getElementById(a)}catch(b){}return c}
function t(a,c,b){a.attachEvent(c,b);E[E.length]=[a,c,b]}function D(a){var c=l.pv;a=a.split(".");a[0]=parseInt(a[0],10);a[1]=parseInt(a[1],10)||0;a[2]=parseInt(a[2],10)||0;return c[0]>a[0]||c[0]==a[0]&&c[1]>a[1]||c[0]==a[0]&&c[1]==a[1]&&c[2]>=a[2]?!0:!1}function k(a,c,b,h){if(!l.ie||!l.mac){var e=m.getElementsByTagName("head")[0];e&&(b=b&&"string"==typeof b?b:"screen",h&&(M=y=null),y&&M==b||(h=m.createElement("style"),h.setAttribute("type","text/css"),h.setAttribute("media",b),y=e.appendChild(h),
l.ie&&l.win&&typeof m.styleSheets!=u&&0<m.styleSheets.length&&(y=m.styleSheets[m.styleSheets.length-1]),M=b),l.ie&&l.win?y&&typeof y.addRule==x&&y.addRule(a,c):y&&typeof m.createTextNode!=u&&y.appendChild(m.createTextNode(a+" {"+c+"}")))}}function B(a,c){if(Q){var b=c?"visible":"hidden";C&&h(a)?h(a).style.visibility=b:k("#"+a,"visibility:"+b)}}function N(a){return null!=/[\\\"<>\.;]/.exec(a)&&typeof encodeURIComponent!=u?encodeURIComponent(a):a}var u="undefined",x="object",G="application/x-shockwave-flash",
P="SWFObjectExprInst",w=window,m=document,A=navigator,R=!1,H=[function(){R?n():b()}],z=[],K=[],E=[],F,J,L,O,C=!1,I=!1,y,M,Q=!0,l=function(){var a=typeof m.getElementById!=u&&typeof m.getElementsByTagName!=u&&typeof m.createElement!=u,c=A.userAgent.toLowerCase(),b=A.platform.toLowerCase(),h=b?/win/.test(b):/win/.test(c),b=b?/mac/.test(b):/mac/.test(c),c=/webkit/.test(c)?parseFloat(c.replace(/^.*webkit\/(\d+(\.\d+)?).*$/,"$1")):!1,e=!+"\v1",f=[0,0,0],d=null;if(typeof A.plugins!=u&&typeof A.plugins["Shockwave Flash"]==
x)!(d=A.plugins["Shockwave Flash"].description)||typeof A.mimeTypes!=u&&A.mimeTypes[G]&&!A.mimeTypes[G].enabledPlugin||(R=!0,e=!1,d=d.replace(/^.*\s+(\S+\s+\S+$)/,"$1"),f[0]=parseInt(d.replace(/^(.*)\..*$/,"$1"),10),f[1]=parseInt(d.replace(/^.*\.(.*)\s.*$/,"$1"),10),f[2]=/[a-zA-Z]/.test(d)?parseInt(d.replace(/^.*[a-zA-Z]+(.*)$/,"$1"),10):0);else if(typeof w.ActiveXObject!=u)try{var k=new ActiveXObject("ShockwaveFlash.ShockwaveFlash");k&&(d=k.GetVariable("$version"))&&(e=!0,d=d.split(" ")[1].split(","),
f=[parseInt(d[0],10),parseInt(d[1],10),parseInt(d[2],10)])}catch(g){}return{w3:a,pv:f,wk:c,ie:e,win:h,mac:b}}();(function(){l.w3&&((typeof m.readyState!=u&&"complete"==m.readyState||typeof m.readyState==u&&(m.getElementsByTagName("body")[0]||m.body))&&g(),C||(typeof m.addEventListener!=u&&m.addEventListener("DOMContentLoaded",g,!1),l.ie&&l.win&&(m.attachEvent("onreadystatechange",function(){"complete"==m.readyState&&(m.detachEvent("onreadystatechange",arguments.callee),g())}),w==top&&function(){if(!C){try{m.documentElement.doScroll("left")}catch(a){setTimeout(arguments.callee,
0);return}g()}}()),l.wk&&function(){C||(/loaded|complete/.test(m.readyState)?g():setTimeout(arguments.callee,0))}(),f(g)))})();(function(){l.ie&&l.win&&window.attachEvent("onunload",function(){for(var a=E.length,b=0;b<a;b++)E[b][0].detachEvent(E[b][1],E[b][2]);a=K.length;for(b=0;b<a;b++)c(K[b]);for(var h in l)l[h]=null;l=null;for(var e in swfobject)swfobject[e]=null;swfobject=null})})();return{registerObject:function(a,c,b,h){if(l.w3&&a&&c){var e={};e.id=a;e.swfVersion=c;e.expressInstall=b;e.callbackFn=
h;z[z.length]=e;B(a,!1)}else h&&h({success:!1,id:a})},getObjectById:function(a){if(l.w3)return e(a)},embedSWF:function(c,b,h,e,f,k,g,t,m,n){var r={success:!1,id:b};l.w3&&!(l.wk&&312>l.wk)&&c&&b&&h&&e&&f?(B(b,!1),d(function(){h+="";e+="";var d={};if(m&&typeof m===x)for(var l in m)d[l]=m[l];d.data=c;d.width=h;d.height=e;l={};if(t&&typeof t===x)for(var v in t)l[v]=t[v];if(g&&typeof g===x)for(var w in g)l.flashvars=typeof l.flashvars!=u?l.flashvars+("&"+w+"="+g[w]):w+"="+g[w];if(D(f))v=a(d,l,b),d.id==
b&&B(b,!0),r.success=!0,r.ref=v;else{if(k&&p()){d.data=k;q(d,l,b,n);return}B(b,!0)}n&&n(r)})):n&&n(r)},switchOffAutoHideShow:function(){Q=!1},ua:l,getFlashPlayerVersion:function(){return{major:l.pv[0],minor:l.pv[1],release:l.pv[2]}},hasFlashPlayerVersion:D,createSWF:function(c,b,h){if(l.w3)return a(c,b,h)},showExpressInstall:function(a,c,b,h){l.w3&&p()&&q(a,c,b,h)},removeSWF:function(a){l.w3&&c(a)},createCSS:function(a,c,b,h){l.w3&&k(a,c,b,h)},addDomLoadEvent:d,addLoadEvent:f,getQueryParamValue:function(a){var c=
m.location.search||m.location.hash;if(c){/\?/.test(c)&&(c=c.split("?")[1]);if(null==a)return N(c);for(var c=c.split("&"),b=0;b<c.length;b++)if(c[b].substring(0,c[b].indexOf("="))==a)return N(c[b].substring(c[b].indexOf("=")+1))}return""},expressInstallCallback:function(){if(I){var a=h(P);a&&F&&(a.parentNode.replaceChild(F,a),J&&(B(J,!0),l.ie&&l.win&&(F.style.display="block")),L&&L(O));I=!1}}}}();function murmurhash3_32_gc(g,d){var f,n,b,e,p;f=g.length&3;n=g.length-f;b=d;for(p=0;p<n;)e=g.charCodeAt(p)&255|(g.charCodeAt(++p)&255)<<8|(g.charCodeAt(++p)&255)<<16|(g.charCodeAt(++p)&255)<<24,++p,e=3432918353*(e&65535)+((3432918353*(e>>>16)&65535)<<16)&4294967295,e=e<<15|e>>>17,e=461845907*(e&65535)+((461845907*(e>>>16)&65535)<<16)&4294967295,b^=e,b=b<<13|b>>>19,b=5*(b&65535)+((5*(b>>>16)&65535)<<16)&4294967295,b=(b&65535)+27492+(((b>>>16)+58964&65535)<<16);e=0;switch(f){case 3:e^=(g.charCodeAt(p+
2)&255)<<16;case 2:e^=(g.charCodeAt(p+1)&255)<<8;case 1:e^=g.charCodeAt(p)&255,e=3432918353*(e&65535)+((3432918353*(e>>>16)&65535)<<16)&4294967295,e=e<<15|e>>>17,b^=461845907*(e&65535)+((461845907*(e>>>16)&65535)<<16)&4294967295}b^=g.length;b^=b>>>16;b=2246822507*(b&65535)+((2246822507*(b>>>16)&65535)<<16)&4294967295;b^=b>>>13;b=3266489909*(b&65535)+((3266489909*(b>>>16)&65535)<<16)&4294967295;return(b^b>>>16)>>>0};var deployJava=function(){function g(a){p.debug&&(console.log?console.log(a):alert(a))}function d(a){if(null==a||0==a.length)return"http://java.com/dt-redirect";"&"==a.charAt(0)&&(a=a.substring(1,a.length));return"http://java.com/dt-redirect?"+a}var f=["id","class","title","style"];"classid codebase codetype data type archive declare standby height width usemap name tabindex align border hspace vspace".split(" ").concat(f,["lang","dir"],"onclick ondblclick onmousedown onmouseup onmouseover onmousemove onmouseout onkeypress onkeydown onkeyup".split(" "));
var n="codebase code name archive object width height alt align hspace vspace".split(" ").concat(f),b;try{b=-1!=document.location.protocol.indexOf("http")?"//java.com/js/webstart.png":"http://java.com/js/webstart.png"}catch(e){b="http://java.com/js/webstart.png"}var p={debug:null,version:"20120801",firefoxJavaVersion:null,myInterval:null,preInstallJREList:null,returnPage:null,brand:null,locale:null,installType:null,EAInstallEnabled:!1,EarlyAccessURL:null,oldMimeType:"application/npruntime-scriptable-plugin;DeploymentToolkit",
mimeType:"application/java-deployment-toolkit",launchButtonPNG:b,browserName:null,browserName2:null,getJREs:function(){var a=[];if(this.isPluginInstalled())for(var c=this.getPlugin().jvms,b=0;b<c.getLength();b++)a[b]=c.get(b).version;else c=this.getBrowser(),"MSIE"==c?this.testUsingActiveX("1.7.0")?a[0]="1.7.0":this.testUsingActiveX("1.6.0")?a[0]="1.6.0":this.testUsingActiveX("1.5.0")?a[0]="1.5.0":this.testUsingActiveX("1.4.2")?a[0]="1.4.2":this.testForMSVM()&&(a[0]="1.1"):"Netscape Family"==c&&(this.getJPIVersionUsingMimeType(),
null!=this.firefoxJavaVersion?a[0]=this.firefoxJavaVersion:this.testUsingMimeTypes("1.7")?a[0]="1.7.0":this.testUsingMimeTypes("1.6")?a[0]="1.6.0":this.testUsingMimeTypes("1.5")?a[0]="1.5.0":this.testUsingMimeTypes("1.4.2")?a[0]="1.4.2":"Safari"==this.browserName2&&(this.testUsingPluginsArray("1.7.0")?a[0]="1.7.0":this.testUsingPluginsArray("1.6")?a[0]="1.6.0":this.testUsingPluginsArray("1.5")?a[0]="1.5.0":this.testUsingPluginsArray("1.4.2")&&(a[0]="1.4.2")));if(this.debug)for(b=0;b<a.length;++b)g("[getJREs()] We claim to have detected Java SE "+
a[b]);return a},installJRE:function(a,c){if(this.isPluginInstalled()&&this.isAutoInstallEnabled(a)){var b=!1;if(b=this.isCallbackSupported()?this.getPlugin().installJRE(a,c):this.getPlugin().installJRE(a))this.refresh(),null!=this.returnPage&&(document.location=this.returnPage);return b}return this.installLatestJRE()},isAutoInstallEnabled:function(a){if(!this.isPluginInstalled())return!1;"undefined"==typeof a&&(a=null);var c;if("MSIE"!=deployJava.browserName||deployJava.compareVersionToPattern(deployJava.getPlugin().version,
["10","0","0"],!1,!0))c=!0;else if(null==a)c=!1;else{c="1.6.0_33+";if(null==c||0==c.length)c=!0;else{var b=c.charAt(c.length-1);"+"!=b&&"*"!=b&&-1!=c.indexOf("_")&&"_"!=b&&(c+="*",b="*");c=c.substring(0,c.length-1);if(0<c.length){var e=c.charAt(c.length-1);if("."==e||"_"==e)c=c.substring(0,c.length-1)}c="*"==b?0==a.indexOf(c):"+"==b?c<=a:!1}c=!c}return c},isCallbackSupported:function(){return this.isPluginInstalled()&&this.compareVersionToPattern(this.getPlugin().version,["10","2","0"],!1,!0)},installLatestJRE:function(a){if(this.isPluginInstalled()&&
this.isAutoInstallEnabled()){var c=!1;if(c=this.isCallbackSupported()?this.getPlugin().installLatestJRE(a):this.getPlugin().installLatestJRE())this.refresh(),null!=this.returnPage&&(document.location=this.returnPage);return c}a=this.getBrowser();c=navigator.platform.toLowerCase();if("true"==this.EAInstallEnabled&&-1!=c.indexOf("win")&&null!=this.EarlyAccessURL)this.preInstallJREList=this.getJREs(),null!=this.returnPage&&(this.myInterval=setInterval("deployJava.poll()",3E3)),location.href=this.EarlyAccessURL;
else{if("MSIE"==a)return this.IEInstall();if("Netscape Family"==a&&-1!=c.indexOf("win32"))return this.FFInstall();location.href=d((null!=this.returnPage?"&returnPage="+this.returnPage:"")+(null!=this.locale?"&locale="+this.locale:"")+(null!=this.brand?"&brand="+this.brand:""))}return!1},runApplet:function(a,c,b){if("undefined"==b||null==b)b="1.1";var e=b.match("^(\\d+)(?:\\.(\\d+)(?:\\.(\\d+)(?:_(\\d+))?)?)?$");null==this.returnPage&&(this.returnPage=document.location);null!=e?"?"!=this.getBrowser()?
this.versionCheck(b+"+")?this.writeAppletTag(a,c):this.installJRE(b+"+")&&(this.refresh(),location.href=document.location,this.writeAppletTag(a,c)):this.writeAppletTag(a,c):g("[runApplet()] Invalid minimumVersion argument to runApplet():"+b)},writeAppletTag:function(a,c){var b="<applet ",e="",d=!0;if(null==c||"object"!=typeof c)c={};for(var f in a){var g;a:{g=f.toLowerCase();for(var p=n.length,q=0;q<p;q++)if(n[q]===g){g=!0;break a}g=!1}g?(b+=" "+f+'="'+a[f]+'"',"code"==f&&(d=!1)):c[f]=a[f]}f=!1;for(var r in c){"codebase_lookup"==
r&&(f=!0);if("object"==r||"java_object"==r||"java_code"==r)d=!1;e+='<param name="'+r+'" value="'+c[r]+'"/>'}f||(e+='<param name="codebase_lookup" value="false"/>');d&&(b+=' code="dummy"');document.write(b+">\n"+e+"\n</applet>")},versionCheck:function(a){var c=0,b=a.match("^(\\d+)(?:\\.(\\d+)(?:\\.(\\d+)(?:_(\\d+))?)?)?(\\*|\\+)?$");if(null!=b){for(var e=a=!1,d=[],f=1;f<b.length;++f)"string"==typeof b[f]&&""!=b[f]&&(d[c]=b[f],c++);"+"==d[d.length-1]?(e=!0,a=!1,d.length--):"*"==d[d.length-1]?(e=!1,
a=!0,d.length--):4>d.length&&(e=!1,a=!0);c=this.getJREs();for(f=0;f<c.length;++f)if(this.compareVersionToPattern(c[f],d,a,e))return!0}else c="Invalid versionPattern passed to versionCheck: "+a,g("[versionCheck()] "+c),alert(c);return!1},isWebStartInstalled:function(a){if("?"==this.getBrowser())return!0;if("undefined"==a||null==a)a="1.4.2";var c=!1;null!=a.match("^(\\d+)(?:\\.(\\d+)(?:\\.(\\d+)(?:_(\\d+))?)?)?$")?c=this.versionCheck(a+"+"):(g("[isWebStartInstaller()] Invalid minimumVersion argument to isWebStartInstalled(): "+
a),c=this.versionCheck("1.4.2+"));return c},getJPIVersionUsingMimeType:function(){for(var a=0;a<navigator.mimeTypes.length;++a){var c=navigator.mimeTypes[a].type.match(/^application\/x-java-applet;jpi-version=(.*)$/);if(null!=c&&(this.firefoxJavaVersion=c[1],"Opera"!=this.browserName2))break}},launchWebStartApplication:function(a){navigator.userAgent.toLowerCase();this.getJPIVersionUsingMimeType();if(!1==this.isWebStartInstalled("1.7.0")&&(!1==this.installJRE("1.7.0+")||!1==this.isWebStartInstalled("1.7.0")))return!1;
var c=null;document.documentURI&&(c=document.documentURI);null==c&&(c=document.URL);var b=this.getBrowser(),e;"MSIE"==b?e='<object classid="clsid:8AD9C840-044E-11D1-B3E9-00805F499D93" width="0" height="0"><PARAM name="launchjnlp" value="'+a+'"><PARAM name="docbase" value="'+c+'"></object>':"Netscape Family"==b&&(e='<embed type="application/x-java-applet;jpi-version='+this.firefoxJavaVersion+'" width="0" height="0" launchjnlp="'+a+'"docbase="'+c+'" />');"undefined"==document.body||null==document.body?
(document.write(e),document.location=c):(a=document.createElement("div"),a.id="div1",a.style.position="relative",a.style.left="-10000px",a.style.margin="0px auto",a.className="dynamicDiv",a.innerHTML=e,document.body.appendChild(a))},createWebStartLaunchButtonEx:function(a,c){null==this.returnPage&&(this.returnPage=a);document.write('<a href="'+("javascript:deployJava.launchWebStartApplication('"+a+"');")+'" onMouseOver="window.status=\'\'; return true;"><img src="'+this.launchButtonPNG+'" border="0" /></a>')},
createWebStartLaunchButton:function(a,c){null==this.returnPage&&(this.returnPage=a);document.write('<a href="'+("javascript:if (!deployJava.isWebStartInstalled(&quot;"+c+"&quot;)) {if (deployJava.installLatestJRE()) {if (deployJava.launch(&quot;"+a+"&quot;)) {}}} else {if (deployJava.launch(&quot;"+a+"&quot;)) {}}")+'" onMouseOver="window.status=\'\'; return true;"><img src="'+this.launchButtonPNG+'" border="0" /></a>')},launch:function(a){document.location=a;return!0},isPluginInstalled:function(){var a=
this.getPlugin();return a&&a.jvms?!0:!1},isAutoUpdateEnabled:function(){return this.isPluginInstalled()?this.getPlugin().isAutoUpdateEnabled():!1},setAutoUpdateEnabled:function(){return this.isPluginInstalled()?this.getPlugin().setAutoUpdateEnabled():!1},setInstallerType:function(a){this.installType=a;return this.isPluginInstalled()?this.getPlugin().setInstallerType(a):!1},setAdditionalPackages:function(a){return this.isPluginInstalled()?this.getPlugin().setAdditionalPackages(a):!1},setEarlyAccess:function(a){this.EAInstallEnabled=
a},isPlugin2:function(){if(this.isPluginInstalled()&&this.versionCheck("1.6.0_10+"))try{return this.getPlugin().isPlugin2()}catch(a){}return!1},allowPlugin:function(){this.getBrowser();return"Safari"!=this.browserName2&&"Opera"!=this.browserName2},getPlugin:function(){this.refresh();var a=null;this.allowPlugin()&&(a=document.getElementById("deployJavaPlugin"));return a},compareVersionToPattern:function(a,c,b,e){if(void 0==a||void 0==c)return!1;var d=a.match("^(\\d+)(?:\\.(\\d+)(?:\\.(\\d+)(?:_(\\d+))?)?)?$");
if(null!=d){var f=0;a=[];for(var g=1;g<d.length;++g)"string"==typeof d[g]&&""!=d[g]&&(a[f]=d[g],f++);d=Math.min(a.length,c.length);if(e){for(g=0;g<d;++g){if(a[g]<c[g])return!1;if(a[g]>c[g])break}return!0}for(g=0;g<d;++g)if(a[g]!=c[g])return!1;return b?!0:a.length==c.length}return!1},getBrowser:function(){if(null==this.browserName){var a=navigator.userAgent.toLowerCase();g("[getBrowser()] navigator.userAgent.toLowerCase() -> "+a);-1!=a.indexOf("msie")&&-1==a.indexOf("opera")?this.browserName2=this.browserName=
"MSIE":-1!=a.indexOf("iphone")?(this.browserName="Netscape Family",this.browserName2="iPhone"):-1!=a.indexOf("firefox")&&-1==a.indexOf("opera")?(this.browserName="Netscape Family",this.browserName2="Firefox"):-1!=a.indexOf("chrome")?(this.browserName="Netscape Family",this.browserName2="Chrome"):-1!=a.indexOf("safari")?(this.browserName="Netscape Family",this.browserName2="Safari"):-1!=a.indexOf("mozilla")&&-1==a.indexOf("opera")?(this.browserName="Netscape Family",this.browserName2="Other"):-1!=
a.indexOf("opera")?(this.browserName="Netscape Family",this.browserName2="Opera"):(this.browserName="?",this.browserName2="unknown");g("[getBrowser()] Detected browser name:"+this.browserName+", "+this.browserName2)}return this.browserName},testUsingActiveX:function(a){a="JavaWebStart.isInstalled."+a+".0";if("undefined"==typeof ActiveXObject||!ActiveXObject)return g("[testUsingActiveX()] Browser claims to be IE, but no ActiveXObject object?"),!1;try{return null!=new ActiveXObject(a)}catch(c){return!1}},
testForMSVM:function(){if("undefined"!=typeof oClientCaps){var a=oClientCaps.getComponentVersion("{08B0E5C0-4FCB-11CF-AAA5-00401C608500}","ComponentID");return""==a||"5,0,5000,0"==a?!1:!0}return!1},testUsingMimeTypes:function(a){if(!navigator.mimeTypes)return g("[testUsingMimeTypes()] Browser claims to be Netscape family, but no mimeTypes[] array?"),!1;for(var c=0;c<navigator.mimeTypes.length;++c){s=navigator.mimeTypes[c].type;var b=s.match(/^application\/x-java-applet\x3Bversion=(1\.8|1\.7|1\.6|1\.5|1\.4\.2)$/);
if(null!=b&&this.compareVersions(b[1],a))return!0}return!1},testUsingPluginsArray:function(a){if(!navigator.plugins||!navigator.plugins.length)return!1;for(var c=navigator.platform.toLowerCase(),b=0;b<navigator.plugins.length;++b)if(s=navigator.plugins[b].description,-1!=s.search(/^Java Switchable Plug-in (Cocoa)/)){if(this.compareVersions("1.5.0",a))return!0}else if(-1!=s.search(/^Java/)&&-1!=c.indexOf("win")&&(this.compareVersions("1.5.0",a)||this.compareVersions("1.6.0",a)))return!0;return this.compareVersions("1.5.0",
a)?!0:!1},IEInstall:function(){location.href=d((null!=this.returnPage?"&returnPage="+this.returnPage:"")+(null!=this.locale?"&locale="+this.locale:"")+(null!=this.brand?"&brand="+this.brand:""));return!1},done:function(a,c){},FFInstall:function(){location.href=d((null!=this.returnPage?"&returnPage="+this.returnPage:"")+(null!=this.locale?"&locale="+this.locale:"")+(null!=this.brand?"&brand="+this.brand:"")+(null!=this.installType?"&type="+this.installType:""));return!1},compareVersions:function(a,
c){for(var b=a.split("."),e=c.split("."),d=0;d<b.length;++d)b[d]=Number(b[d]);for(d=0;d<e.length;++d)e[d]=Number(e[d]);2==b.length&&(b[2]=0);return b[0]>e[0]?!0:b[0]<e[0]?!1:b[1]>e[1]?!0:b[1]<e[1]?!1:b[2]>e[2]?!0:b[2]<e[2]?!1:!0},enableAlerts:function(){this.browserName=null;this.debug=!0},poll:function(){this.refresh();var a=this.getJREs();0==this.preInstallJREList.length&&0!=a.length&&(clearInterval(this.myInterval),null!=this.returnPage&&(location.href=this.returnPage));0!=this.preInstallJREList.length&&
0!=a.length&&this.preInstallJREList[0]!=a[0]&&(clearInterval(this.myInterval),null!=this.returnPage&&(location.href=this.returnPage))},writePluginTag:function(){var a=this.getBrowser();"MSIE"==a?document.write('<object classid="clsid:CAFEEFAC-DEC7-0000-0001-ABCDEFFEDCBA" id="deployJavaPlugin" width="0" height="0"></object>'):"Netscape Family"==a&&this.allowPlugin()&&this.writeEmbedTag()},refresh:function(){navigator.plugins.refresh(!1);"Netscape Family"==this.getBrowser()&&this.allowPlugin()&&null==
document.getElementById("deployJavaPlugin")&&this.writeEmbedTag()},writeEmbedTag:function(){var a=!1;if(null!=navigator.mimeTypes){for(var b=0;b<navigator.mimeTypes.length;b++)navigator.mimeTypes[b].type==this.mimeType&&navigator.mimeTypes[b].enabledPlugin&&(document.write('<embed id="deployJavaPlugin" type="'+this.mimeType+'" hidden="true" />'),a=!0);if(!a)for(b=0;b<navigator.mimeTypes.length;b++)navigator.mimeTypes[b].type==this.oldMimeType&&navigator.mimeTypes[b].enabledPlugin&&document.write('<embed id="deployJavaPlugin" type="'+
this.oldMimeType+'" hidden="true" />')}}};p.writePluginTag();if(null==p.locale){f=null;if(null==f)try{f=navigator.userLanguage}catch(q){}if(null==f)try{f=navigator.systemLanguage}catch(r){}if(null==f)try{f=navigator.language}catch(v){}null!=f&&(f.replace("-","_"),p.locale=f)}return p}();(function(g){var d,f,n=function(){d=(new (window.UAParser||exports.UAParser)).getResult();f=new Detector;return this};n.prototype={getSoftwareVersion:function(){return"ClientJS 0.1.8"},getBrowserData:function(){return d},getFingerprint:function(){var b=d.ua,e=this.getScreenPrint(),f=this.getPlugins(),g=this.getFonts(),n=this.isLocalStorage(),v=this.isSessionStorage(),a=this.getTimeZone(),c=this.getLanguage(),h=this.getSystemLanguage(),t=this.isCookie(),D=this.getCanvasPrint();return murmurhash3_32_gc(b+
"|"+e+"|"+f+"|"+g+"|"+n+"|"+v+"|"+a+"|"+c+"|"+h+"|"+t+"|"+D,256)},getCustomFingerprint:function(){var b="";for(i=0;i<arguments.length;i++)i+1!=arguments.length&&(b+=arguments[i]+"|");return murmurhash3_32_gc(b,256)},getUserAgent:function(){return d.ua},getUserAgentLowerCase:function(){return d.ua.toLowerCase()},getBrowser:function(){return d.browser.name},getBrowserVersion:function(){return d.browser.version},getBrowserMajorVersion:function(){return d.browser.major},isIE:function(){return/IE/i.test(d.browser.name)},
isChrome:function(){return/Chrome/i.test(d.browser.name)},isFirefox:function(){return/Firefox/i.test(d.browser.name)},isSafari:function(){return/Safari/i.test(d.browser.name)},isOpera:function(){return/Opera/i.test(d.browser.name)},getEngine:function(){return d.engine.name},getEngineVersion:function(){return d.engine.version},getOS:function(){return d.os.name},getOSVersion:function(){return d.os.version},isWindows:function(){return/Windows/i.test(d.os.name)},isMac:function(){return/Mac/i.test(d.os.name)},
isLinux:function(){return/Linux/i.test(d.os.name)},isUbuntu:function(){return/Ubuntu/i.test(d.os.name)},isSolaris:function(){return/Solaris/i.test(d.os.name)},getDevice:function(){return d.device.model},getDeviceType:function(){return d.device.type},getDeviceVendor:function(){return d.device.vendor},getCPU:function(){return d.cpu.architecture},isMobile:function(){var b=d.ua||navigator.vendor||window.opera;return/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(b)||
/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(b.substr(0,
4))},isMobileMajor:function(){return this.isMobileAndroid()||this.isMobileBlackBerry()||this.isMobileIOS()||this.isMobileOpera()||this.isMobileWindows()},isMobileAndroid:function(){return d.ua.match(/Android/i)?!0:!1},isMobileOpera:function(){return d.ua.match(/Opera Mini/i)?!0:!1},isMobileWindows:function(){return d.ua.match(/IEMobile/i)?!0:!1},isMobileBlackBerry:function(){return d.ua.match(/BlackBerry/i)?!0:!1},isMobileIOS:function(){return d.ua.match(/iPhone|iPad|iPod/i)?!0:!1},isIphone:function(){return d.ua.match(/iPhone/i)?
!0:!1},isIpad:function(){return d.ua.match(/iPad/i)?!0:!1},isIpod:function(){return d.ua.match(/iPod/i)?!0:!1},getScreenPrint:function(){return"Current Resolution: "+this.getCurrentResolution()+", Avaiable Resolution: "+this.getAvailableResolution()+", Color Depth: "+this.getColorDepth()+", Device XDPI: "+this.getDeviceXDPI()+", Device YDPI: "+this.getDeviceYDPI()},getColorDepth:function(){return screen.colorDepth},getCurrentResolution:function(){return screen.width+"x"+screen.height},getAvailableResolution:function(){return screen.availWidth+
"x"+screen.availHeight},getDeviceXDPI:function(){return screen.deviceXDPI},getDeviceYDPI:function(){return screen.deviceYDPI},getPlugins:function(){for(var b="",e=0;e<navigator.plugins.length;e++)b=e==navigator.plugins.length-1?b+navigator.plugins[e].name:b+(navigator.plugins[e].name+", ");return b},isJava:function(){return navigator.javaEnabled()},getJavaVersion:function(){return deployJava.getJREs().toString()},isFlash:function(){return navigator.plugins["Shockwave Flash"]?!0:!1},getFlashVersion:function(){return this.isFlash()?
(objPlayerVersion=swfobject.getFlashPlayerVersion(),objPlayerVersion.major+"."+objPlayerVersion.minor+"."+objPlayerVersion.release):""},isSilverlight:function(){return navigator.plugins["Silverlight Plug-In"]?!0:!1},getSilverlightVersion:function(){return this.isSilverlight()?navigator.plugins["Silverlight Plug-In"].description:""},isMimeTypes:function(){return navigator.mimeTypes.length?!0:!1},getMimeTypes:function(){for(var b="",e=0;e<navigator.mimeTypes.length;e++)b=e==navigator.mimeTypes.length-
1?b+navigator.mimeTypes[e].description:b+(navigator.mimeTypes[e].description+", ");return b},isFont:function(b){return f.detect(b)},getFonts:function(){for(var b="Abadi MT Condensed Light;Adobe Fangsong Std;Adobe Hebrew;Adobe Ming Std;Agency FB;Aharoni;Andalus;Angsana New;AngsanaUPC;Aparajita;Arab;Arabic Transparent;Arabic Typesetting;Arial Baltic;Arial Black;Arial CE;Arial CYR;Arial Greek;Arial TUR;Arial;Batang;BatangChe;Bauhaus 93;Bell MT;Bitstream Vera Serif;Bodoni MT;Bookman Old Style;Braggadocio;Broadway;Browallia New;BrowalliaUPC;Calibri Light;Calibri;Californian FB;Cambria Math;Cambria;Candara;Castellar;Casual;Centaur;Century Gothic;Chalkduster;Colonna MT;Comic Sans MS;Consolas;Constantia;Copperplate Gothic Light;Corbel;Cordia New;CordiaUPC;Courier New Baltic;Courier New CE;Courier New CYR;Courier New Greek;Courier New TUR;Courier New;DFKai-SB;DaunPenh;David;DejaVu LGC Sans Mono;Desdemona;DilleniaUPC;DokChampa;Dotum;DotumChe;Ebrima;Engravers MT;Eras Bold ITC;Estrangelo Edessa;EucrosiaUPC;Euphemia;Eurostile;FangSong;Forte;FrankRuehl;Franklin Gothic Heavy;Franklin Gothic Medium;FreesiaUPC;French Script MT;Gabriola;Gautami;Georgia;Gigi;Gisha;Goudy Old Style;Gulim;GulimChe;GungSeo;Gungsuh;GungsuhChe;Haettenschweiler;Harrington;Hei S;HeiT;Heisei Kaku Gothic;Hiragino Sans GB;Impact;Informal Roman;IrisUPC;Iskoola Pota;JasmineUPC;KacstOne;KaiTi;Kalinga;Kartika;Khmer UI;Kino MT;KodchiangUPC;Kokila;Kozuka Gothic Pr6N;Lao UI;Latha;Leelawadee;Levenim MT;LilyUPC;Lohit Gujarati;Loma;Lucida Bright;Lucida Console;Lucida Fax;Lucida Sans Unicode;MS Gothic;MS Mincho;MS PGothic;MS PMincho;MS Reference Sans Serif;MS UI Gothic;MV Boli;Magneto;Malgun Gothic;Mangal;Marlett;Matura MT Script Capitals;Meiryo UI;Meiryo;Menlo;Microsoft Himalaya;Microsoft JhengHei;Microsoft New Tai Lue;Microsoft PhagsPa;Microsoft Sans Serif;Microsoft Tai Le;Microsoft Uighur;Microsoft YaHei;Microsoft Yi Baiti;MingLiU;MingLiU-ExtB;MingLiU_HKSCS;MingLiU_HKSCS-ExtB;Miriam Fixed;Miriam;Mongolian Baiti;MoolBoran;NSimSun;Narkisim;News Gothic MT;Niagara Solid;Nyala;PMingLiU;PMingLiU-ExtB;Palace Script MT;Palatino Linotype;Papyrus;Perpetua;Plantagenet Cherokee;Playbill;Prelude Bold;Prelude Condensed Bold;Prelude Condensed Medium;Prelude Medium;PreludeCompressedWGL Black;PreludeCompressedWGL Bold;PreludeCompressedWGL Light;PreludeCompressedWGL Medium;PreludeCondensedWGL Black;PreludeCondensedWGL Bold;PreludeCondensedWGL Light;PreludeCondensedWGL Medium;PreludeWGL Black;PreludeWGL Bold;PreludeWGL Light;PreludeWGL Medium;Raavi;Rachana;Rockwell;Rod;Sakkal Majalla;Sawasdee;Script MT Bold;Segoe Print;Segoe Script;Segoe UI Light;Segoe UI Semibold;Segoe UI Symbol;Segoe UI;Shonar Bangla;Showcard Gothic;Shruti;SimHei;SimSun;SimSun-ExtB;Simplified Arabic Fixed;Simplified Arabic;Snap ITC;Sylfaen;Symbol;Tahoma;Times New Roman Baltic;Times New Roman CE;Times New Roman CYR;Times New Roman Greek;Times New Roman TUR;Times New Roman;TlwgMono;Traditional Arabic;Trebuchet MS;Tunga;Tw Cen MT Condensed Extra Bold;Ubuntu;Umpush;Univers;Utopia;Utsaah;Vani;Verdana;Vijaya;Vladimir Script;Vrinda;Webdings;Wide Latin;Wingdings".split(";"),
e="",d=0;d<b.length;d++)f.detect(b[d])&&(e=d==b.length-1?e+b[d]:e+(b[d]+", "));return e},isLocalStorage:function(){try{return!!g.localStorage}catch(b){return!0}},isSessionStorage:function(){try{return!!g.sessionStorage}catch(b){return!0}},isCookie:function(){return navigator.cookieEnabled},getTimeZone:function(){return String(String(new Date).split("(")[1]).split(")")[0]},getLanguage:function(){return navigator.language},getSystemLanguage:function(){return navigator.systemLanguage},isCanvas:function(){var b=
document.createElement("canvas");try{return!(!b.getContext||!b.getContext("2d"))}catch(d){return!1}},getCanvasPrint:function(){var b=document.createElement("canvas"),d;try{d=b.getContext("2d")}catch(f){return""}d.textBaseline="top";d.font="14px 'Arial'";d.textBaseline="alphabetic";d.fillStyle="#f60";d.fillRect(125,1,62,20);d.fillStyle="#069";d.fillText("http://valve.github.io",2,15);d.fillStyle="rgba(102, 204, 0, 0.7)";d.fillText("http://valve.github.io",4,17);return b.toDataURL()}};"object"===typeof module&&
"undefined"!==typeof exports&&(module.exports=n);g.ClientJS=n})(window);

/* arabic */
@font-face {
  font-family: 'Changa';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/changa/v9/2-c79JNi2YuVOUcOarRPgnNGooxCZ62xcjLj9ytf.woff2) format('woff2');
  unicode-range: U+0600-06FF, U+200C-200E, U+2010-2011, U+204F, U+2E41, U+FB50-FDFF, U+FE80-FEFC;
}
/* latin-ext */
@font-face {
  font-family: 'Changa';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/changa/v9/2-c79JNi2YuVOUcOarRPgnNGooxCZ62xcjnj9ytf.woff2) format('woff2');
  unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
/* latin */
@font-face {
  font-family: 'Changa';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/changa/v9/2-c79JNi2YuVOUcOarRPgnNGooxCZ62xcjfj9w.woff2) format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}



@font-face{font-family:'jazeera';src: url('https://www.fontstatic.com/fonts/jazeera/jazeera.eot?#iefix');src: local('الجزيرة'), local('jazeera'),url('https://www.fontstatic.com/fonts/jazeera/jazeera.woff') format('woff');}@font-face{font-family:'jazeera-light';src: url('https://www.fontstatic.com/fonts/jazeera-light/jazeera-light.eot?#iefix');src: local('الجزيرة خفيف'), local('jazeera-light'),url('https://www.fontstatic.com/fonts/jazeera-light/jazeera-light.woff') format('woff');}
/*!
 *  Font Awesome 4.5.0 by @davegandy - http://fontawesome.io - @fontawesome
 *  License - http://fontawesome.io/license (Font: SIL OFL 1.1, CSS: MIT License)
 */@font-face{font-family:'FontAwesome';src:url('../fonts/fontawesome-webfont3295.eot?v=4.5.0');src:url('../fonts/fontawesome-webfontd41d.eot?#iefix&v=4.5.0') format('embedded-opentype'),url('../fonts/fontawesome-webfont3295.woff2?v=4.5.0') format('woff2'),url('../fonts/fontawesome-webfont3295.woff?v=4.5.0') format('woff'),url('../fonts/fontawesome-webfont3295.ttf?v=4.5.0') format('truetype'),url('../fonts/fontawesome-webfont3295.svg?v=4.5.0#fontawesomeregular') format('svg');font-weight:normal;font-style:normal}.fa{display:inline-block;font:normal normal normal 14px/1 FontAwesome;font-size:inherit;text-rendering:auto;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.fa-lg{font-size:1.33333333em;line-height:.75em;vertical-align:-15%}.fa-2x{font-size:2em}.fa-3x{font-size:3em}.fa-4x{font-size:4em}.fa-5x{font-size:5em}.fa-fw{width:1.28571429em;text-align:center}.fa-ul{padding-left:0;margin-left:2.14285714em;list-style-type:none}.fa-ul>li{position:relative}.fa-li{position:absolute;left:-2.14285714em;width:2.14285714em;top:.14285714em;text-align:center}.fa-li.fa-lg{left:-1.85714286em}.fa-border{padding:.2em .25em .15em;border:solid .08em #eee;border-radius:.1em}.fa-pull-left{float:left}.fa-pull-right{float:right}.fa.fa-pull-left{margin-right:.3em}.fa.fa-pull-right{margin-left:.3em}.pull-right{float:right}.pull-left{float:left}.fa.pull-left{margin-right:.3em}.fa.pull-right{margin-left:.3em}.fa-spin{-webkit-animation:fa-spin 2s infinite linear;animation:fa-spin 2s infinite linear}.fa-pulse{-webkit-animation:fa-spin 1s infinite steps(8);animation:fa-spin 1s infinite steps(8)}@-webkit-keyframes fa-spin{0%{-webkit-transform:rotate(0deg);transform:rotate(0deg)}100%{-webkit-transform:rotate(359deg);transform:rotate(359deg)}}@keyframes fa-spin{0%{-webkit-transform:rotate(0deg);transform:rotate(0deg)}100%{-webkit-transform:rotate(359deg);transform:rotate(359deg)}}.fa-rotate-90{filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=1);-webkit-transform:rotate(90deg);-ms-transform:rotate(90deg);transform:rotate(90deg)}.fa-rotate-180{filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=2);-webkit-transform:rotate(180deg);-ms-transform:rotate(180deg);transform:rotate(180deg)}.fa-rotate-270{filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=3);-webkit-transform:rotate(270deg);-ms-transform:rotate(270deg);transform:rotate(270deg)}.fa-flip-horizontal{filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=0, mirror=1);-webkit-transform:scale(-1, 1);-ms-transform:scale(-1, 1);transform:scale(-1, 1)}.fa-flip-vertical{filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=2, mirror=1);-webkit-transform:scale(1, -1);-ms-transform:scale(1, -1);transform:scale(1, -1)}:root .fa-rotate-90,:root .fa-rotate-180,:root .fa-rotate-270,:root .fa-flip-horizontal,:root .fa-flip-vertical{filter:none}.fa-stack{position:relative;display:inline-block;width:2em;height:2em;line-height:2em;vertical-align:middle}.fa-stack-1x,.fa-stack-2x{position:absolute;left:0;width:100%;text-align:center}.fa-stack-1x{line-height:inherit}.fa-stack-2x{font-size:2em}.fa-inverse{color:#fff}.fa-glass:before{content:"\f000"}.fa-music:before{content:"\f001"}.fa-search:before{content:"\f002"}.fa-envelope-o:before{content:"\f003"}.fa-heart:before{content:"\f004"}.fa-star:before{content:"\f005"}.fa-star-o:before{content:"\f006"}.fa-user:before{content:"\f007"}.fa-film:before{content:"\f008"}.fa-th-large:before{content:"\f009"}.fa-th:before{content:"\f00a"}.fa-th-list:before{content:"\f00b"}.fa-check:before{content:"\f00c"}.fa-remove:before,.fa-close:before,.fa-times:before{content:"\f00d"}.fa-search-plus:before{content:"\f00e"}.fa-search-minus:before{content:"\f010"}.fa-power-off:before{content:"\f011"}.fa-signal:before{content:"\f012"}.fa-gear:before,.fa-cog:before{content:"\f013"}.fa-trash-o:before{content:"\f014"}.fa-home:before{content:"\f015"}.fa-file-o:before{content:"\f016"}.fa-clock-o:before{content:"\f017"}.fa-road:before{content:"\f018"}.fa-download:before{content:"\f019"}.fa-arrow-circle-o-down:before{content:"\f01a"}.fa-arrow-circle-o-up:before{content:"\f01b"}.fa-inbox:before{content:"\f01c"}.fa-play-circle-o:before{content:"\f01d"}.fa-rotate-right:before,.fa-repeat:before{content:"\f01e"}.fa-refresh:before{content:"\f021"}.fa-list-alt:before{content:"\f022"}.fa-lock:before{content:"\f023"}.fa-flag:before{content:"\f024"}.fa-headphones:before{content:"\f025"}.fa-volume-off:before{content:"\f026"}.fa-volume-down:before{content:"\f027"}.fa-volume-up:before{content:"\f028"}.fa-qrcode:before{content:"\f029"}.fa-barcode:before{content:"\f02a"}.fa-tag:before{content:"\f02b"}.fa-tags:before{content:"\f02c"}.fa-book:before{content:"\f02d"}.fa-bookmark:before{content:"\f02e"}.fa-print:before{content:"\f02f"}.fa-camera:before{content:"\f030"}.fa-font:before{content:"\f031"}.fa-bold:before{content:"\f032"}.fa-italic:before{content:"\f033"}.fa-text-height:before{content:"\f034"}.fa-text-width:before{content:"\f035"}.fa-align-left:before{content:"\f036"}.fa-align-center:before{content:"\f037"}.fa-align-right:before{content:"\f038"}.fa-align-justify:before{content:"\f039"}.fa-list:before{content:"\f03a"}.fa-dedent:before,.fa-outdent:before{content:"\f03b"}.fa-indent:before{content:"\f03c"}.fa-video-camera:before{content:"\f03d"}.fa-photo:before,.fa-image:before,.fa-picture-o:before{content:"\f03e"}.fa-pencil:before{content:"\f040"}.fa-map-marker:before{content:"\f041"}.fa-adjust:before{content:"\f042"}.fa-tint:before{content:"\f043"}.fa-edit:before,.fa-pencil-square-o:before{content:"\f044"}.fa-share-square-o:before{content:"\f045"}.fa-check-square-o:before{content:"\f046"}.fa-arrows:before{content:"\f047"}.fa-step-backward:before{content:"\f048"}.fa-fast-backward:before{content:"\f049"}.fa-backward:before{content:"\f04a"}.fa-play:before{content:"\f04b"}.fa-pause:before{content:"\f04c"}.fa-stop:before{content:"\f04d"}.fa-forward:before{content:"\f04e"}.fa-fast-forward:before{content:"\f050"}.fa-step-forward:before{content:"\f051"}.fa-eject:before{content:"\f052"}.fa-chevron-left:before{content:"\f053"}.fa-chevron-right:before{content:"\f054"}.fa-plus-circle:before{content:"\f055"}.fa-minus-circle:before{content:"\f056"}.fa-times-circle:before{content:"\f057"}.fa-check-circle:before{content:"\f058"}.fa-question-circle:before{content:"\f059"}.fa-info-circle:before{content:"\f05a"}.fa-crosshairs:before{content:"\f05b"}.fa-times-circle-o:before{content:"\f05c"}.fa-check-circle-o:before{content:"\f05d"}.fa-ban:before{content:"\f05e"}.fa-arrow-left:before{content:"\f060"}.fa-arrow-right:before{content:"\f061"}.fa-arrow-up:before{content:"\f062"}.fa-arrow-down:before{content:"\f063"}.fa-mail-forward:before,.fa-share:before{content:"\f064"}.fa-expand:before{content:"\f065"}.fa-compress:before{content:"\f066"}.fa-plus:before{content:"\f067"}.fa-minus:before{content:"\f068"}.fa-asterisk:before{content:"\f069"}.fa-exclamation-circle:before{content:"\f06a"}.fa-gift:before{content:"\f06b"}.fa-leaf:before{content:"\f06c"}.fa-fire:before{content:"\f06d"}.fa-eye:before{content:"\f06e"}.fa-eye-slash:before{content:"\f070"}.fa-warning:before,.fa-exclamation-triangle:before{content:"\f071"}.fa-plane:before{content:"\f072"}.fa-calendar:before{content:"\f073"}.fa-random:before{content:"\f074"}.fa-comment:before{content:"\f075"}.fa-magnet:before{content:"\f076"}.fa-chevron-up:before{content:"\f077"}.fa-chevron-down:before{content:"\f078"}.fa-retweet:before{content:"\f079"}.fa-shopping-cart:before{content:"\f07a"}.fa-folder:before{content:"\f07b"}.fa-folder-open:before{content:"\f07c"}.fa-arrows-v:before{content:"\f07d"}.fa-arrows-h:before{content:"\f07e"}.fa-bar-chart-o:before,.fa-bar-chart:before{content:"\f080"}.fa-twitter-square:before{content:"\f081"}.fa-facebook-square:before{content:"\f082"}.fa-camera-retro:before{content:"\f083"}.fa-key:before{content:"\f084"}.fa-gears:before,.fa-cogs:before{content:"\f085"}.fa-comments:before{content:"\f086"}.fa-thumbs-o-up:before{content:"\f087"}.fa-thumbs-o-down:before{content:"\f088"}.fa-star-half:before{content:"\f089"}.fa-heart-o:before{content:"\f08a"}.fa-sign-out:before{content:"\f08b"}.fa-linkedin-square:before{content:"\f08c"}.fa-thumb-tack:before{content:"\f08d"}.fa-external-link:before{content:"\f08e"}.fa-sign-in:before{content:"\f090"}.fa-trophy:before{content:"\f091"}.fa-github-square:before{content:"\f092"}.fa-upload:before{content:"\f093"}.fa-lemon-o:before{content:"\f094"}.fa-phone:before{content:"\f095"}.fa-square-o:before{content:"\f096"}.fa-bookmark-o:before{content:"\f097"}.fa-phone-square:before{content:"\f098"}.fa-twitter:before{content:"\f099"}.fa-facebook-f:before,.fa-facebook:before{content:"\f09a"}.fa-github:before{content:"\f09b"}.fa-unlock:before{content:"\f09c"}.fa-credit-card:before{content:"\f09d"}.fa-feed:before,.fa-rss:before{content:"\f09e"}.fa-hdd-o:before{content:"\f0a0"}.fa-bullhorn:before{content:"\f0a1"}.fa-bell:before{content:"\f0f3"}.fa-certificate:before{content:"\f0a3"}.fa-hand-o-right:before{content:"\f0a4"}.fa-hand-o-left:before{content:"\f0a5"}.fa-hand-o-up:before{content:"\f0a6"}.fa-hand-o-down:before{content:"\f0a7"}.fa-arrow-circle-left:before{content:"\f0a8"}.fa-arrow-circle-right:before{content:"\f0a9"}.fa-arrow-circle-up:before{content:"\f0aa"}.fa-arrow-circle-down:before{content:"\f0ab"}.fa-globe:before{content:"\f0ac"}.fa-wrench:before{content:"\f0ad"}.fa-tasks:before{content:"\f0ae"}.fa-filter:before{content:"\f0b0"}.fa-briefcase:before{content:"\f0b1"}.fa-arrows-alt:before{content:"\f0b2"}.fa-group:before,.fa-users:before{content:"\f0c0"}.fa-chain:before,.fa-link:before{content:"\f0c1"}.fa-cloud:before{content:"\f0c2"}.fa-flask:before{content:"\f0c3"}.fa-cut:before,.fa-scissors:before{content:"\f0c4"}.fa-copy:before,.fa-files-o:before{content:"\f0c5"}.fa-paperclip:before{content:"\f0c6"}.fa-save:before,.fa-floppy-o:before{content:"\f0c7"}.fa-square:before{content:"\f0c8"}.fa-navicon:before,.fa-reorder:before,.fa-bars:before{content:"\f0c9"}.fa-list-ul:before{content:"\f0ca"}.fa-list-ol:before{content:"\f0cb"}.fa-strikethrough:before{content:"\f0cc"}.fa-underline:before{content:"\f0cd"}.fa-table:before{content:"\f0ce"}.fa-magic:before{content:"\f0d0"}.fa-truck:before{content:"\f0d1"}.fa-pinterest:before{content:"\f0d2"}.fa-pinterest-square:before{content:"\f0d3"}.fa-google-plus-square:before{content:"\f0d4"}.fa-google-plus:before{content:"\f0d5"}.fa-money:before{content:"\f0d6"}.fa-caret-down:before{content:"\f0d7"}.fa-caret-up:before{content:"\f0d8"}.fa-caret-left:before{content:"\f0d9"}.fa-caret-right:before{content:"\f0da"}.fa-columns:before{content:"\f0db"}.fa-unsorted:before,.fa-sort:before{content:"\f0dc"}.fa-sort-down:before,.fa-sort-desc:before{content:"\f0dd"}.fa-sort-up:before,.fa-sort-asc:before{content:"\f0de"}.fa-envelope:before{content:"\f0e0"}.fa-linkedin:before{content:"\f0e1"}.fa-rotate-left:before,.fa-undo:before{content:"\f0e2"}.fa-legal:before,.fa-gavel:before{content:"\f0e3"}.fa-dashboard:before,.fa-tachometer:before{content:"\f0e4"}.fa-comment-o:before{content:"\f0e5"}.fa-comments-o:before{content:"\f0e6"}.fa-flash:before,.fa-bolt:before{content:"\f0e7"}.fa-sitemap:before{content:"\f0e8"}.fa-umbrella:before{content:"\f0e9"}.fa-paste:before,.fa-clipboard:before{content:"\f0ea"}.fa-lightbulb-o:before{content:"\f0eb"}.fa-exchange:before{content:"\f0ec"}.fa-cloud-download:before{content:"\f0ed"}.fa-cloud-upload:before{content:"\f0ee"}.fa-user-md:before{content:"\f0f0"}.fa-stethoscope:before{content:"\f0f1"}.fa-suitcase:before{content:"\f0f2"}.fa-bell-o:before{content:"\f0a2"}.fa-coffee:before{content:"\f0f4"}.fa-cutlery:before{content:"\f0f5"}.fa-file-text-o:before{content:"\f0f6"}.fa-building-o:before{content:"\f0f7"}.fa-hospital-o:before{content:"\f0f8"}.fa-ambulance:before{content:"\f0f9"}.fa-medkit:before{content:"\f0fa"}.fa-fighter-jet:before{content:"\f0fb"}.fa-beer:before{content:"\f0fc"}.fa-h-square:before{content:"\f0fd"}.fa-plus-square:before{content:"\f0fe"}.fa-angle-double-left:before{content:"\f100"}.fa-angle-double-right:before{content:"\f101"}.fa-angle-double-up:before{content:"\f102"}.fa-angle-double-down:before{content:"\f103"}.fa-angle-left:before{content:"\f104"}.fa-angle-right:before{content:"\f105"}.fa-angle-up:before{content:"\f106"}.fa-angle-down:before{content:"\f107"}.fa-desktop:before{content:"\f108"}.fa-laptop:before{content:"\f109"}.fa-tablet:before{content:"\f10a"}.fa-mobile-phone:before,.fa-mobile:before{content:"\f10b"}.fa-circle-o:before{content:"\f10c"}.fa-quote-left:before{content:"\f10d"}.fa-quote-right:before{content:"\f10e"}.fa-spinner:before{content:"\f110"}.fa-circle:before{content:"\f111"}.fa-mail-reply:before,.fa-reply:before{content:"\f112"}.fa-github-alt:before{content:"\f113"}.fa-folder-o:before{content:"\f114"}.fa-folder-open-o:before{content:"\f115"}.fa-smile-o:before{content:"\f118"}.fa-frown-o:before{content:"\f119"}.fa-meh-o:before{content:"\f11a"}.fa-gamepad:before{content:"\f11b"}.fa-keyboard-o:before{content:"\f11c"}.fa-flag-o:before{content:"\f11d"}.fa-flag-checkered:before{content:"\f11e"}.fa-terminal:before{content:"\f120"}.fa-code:before{content:"\f121"}.fa-mail-reply-all:before,.fa-reply-all:before{content:"\f122"}.fa-star-half-empty:before,.fa-star-half-full:before,.fa-star-half-o:before{content:"\f123"}.fa-location-arrow:before{content:"\f124"}.fa-crop:before{content:"\f125"}.fa-code-fork:before{content:"\f126"}.fa-unlink:before,.fa-chain-broken:before{content:"\f127"}.fa-question:before{content:"\f128"}.fa-info:before{content:"\f129"}.fa-exclamation:before{content:"\f12a"}.fa-superscript:before{content:"\f12b"}.fa-subscript:before{content:"\f12c"}.fa-eraser:before{content:"\f12d"}.fa-puzzle-piece:before{content:"\f12e"}.fa-microphone:before{content:"\f130"}.fa-microphone-slash:before{content:"\f131"}.fa-shield:before{content:"\f132"}.fa-calendar-o:before{content:"\f133"}.fa-fire-extinguisher:before{content:"\f134"}.fa-rocket:before{content:"\f135"}.fa-maxcdn:before{content:"\f136"}.fa-chevron-circle-left:before{content:"\f137"}.fa-chevron-circle-right:before{content:"\f138"}.fa-chevron-circle-up:before{content:"\f139"}.fa-chevron-circle-down:before{content:"\f13a"}.fa-html5:before{content:"\f13b"}.fa-css3:before{content:"\f13c"}.fa-anchor:before{content:"\f13d"}.fa-unlock-alt:before{content:"\f13e"}.fa-bullseye:before{content:"\f140"}.fa-ellipsis-h:before{content:"\f141"}.fa-ellipsis-v:before{content:"\f142"}.fa-rss-square:before{content:"\f143"}.fa-play-circle:before{content:"\f144"}.fa-ticket:before{content:"\f145"}.fa-minus-square:before{content:"\f146"}.fa-minus-square-o:before{content:"\f147"}.fa-level-up:before{content:"\f148"}.fa-level-down:before{content:"\f149"}.fa-check-square:before{content:"\f14a"}.fa-pencil-square:before{content:"\f14b"}.fa-external-link-square:before{content:"\f14c"}.fa-share-square:before{content:"\f14d"}.fa-compass:before{content:"\f14e"}.fa-toggle-down:before,.fa-caret-square-o-down:before{content:"\f150"}.fa-toggle-up:before,.fa-caret-square-o-up:before{content:"\f151"}.fa-toggle-right:before,.fa-caret-square-o-right:before{content:"\f152"}.fa-euro:before,.fa-eur:before{content:"\f153"}.fa-gbp:before{content:"\f154"}.fa-dollar:before,.fa-usd:before{content:"\f155"}.fa-rupee:before,.fa-inr:before{content:"\f156"}.fa-cny:before,.fa-rmb:before,.fa-yen:before,.fa-jpy:before{content:"\f157"}.fa-ruble:before,.fa-rouble:before,.fa-rub:before{content:"\f158"}.fa-won:before,.fa-krw:before{content:"\f159"}.fa-bitcoin:before,.fa-btc:before{content:"\f15a"}.fa-file:before{content:"\f15b"}.fa-file-text:before{content:"\f15c"}.fa-sort-alpha-asc:before{content:"\f15d"}.fa-sort-alpha-desc:before{content:"\f15e"}.fa-sort-amount-asc:before{content:"\f160"}.fa-sort-amount-desc:before{content:"\f161"}.fa-sort-numeric-asc:before{content:"\f162"}.fa-sort-numeric-desc:before{content:"\f163"}.fa-thumbs-up:before{content:"\f164"}.fa-thumbs-down:before{content:"\f165"}.fa-youtube-square:before{content:"\f166"}.fa-youtube:before{content:"\f167"}.fa-xing:before{content:"\f168"}.fa-xing-square:before{content:"\f169"}.fa-youtube-play:before{content:"\f16a"}.fa-dropbox:before{content:"\f16b"}.fa-stack-overflow:before{content:"\f16c"}.fa-instagram:before{content:"\f16d"}.fa-flickr:before{content:"\f16e"}.fa-adn:before{content:"\f170"}.fa-bitbucket:before{content:"\f171"}.fa-bitbucket-square:before{content:"\f172"}.fa-tumblr:before{content:"\f173"}.fa-tumblr-square:before{content:"\f174"}.fa-long-arrow-down:before{content:"\f175"}.fa-long-arrow-up:before{content:"\f176"}.fa-long-arrow-left:before{content:"\f177"}.fa-long-arrow-right:before{content:"\f178"}.fa-apple:before{content:"\f179"}.fa-windows:before{content:"\f17a"}.fa-android:before{content:"\f17b"}.fa-linux:before{content:"\f17c"}.fa-dribbble:before{content:"\f17d"}.fa-skype:before{content:"\f17e"}.fa-foursquare:before{content:"\f180"}.fa-trello:before{content:"\f181"}.fa-female:before{content:"\f182"}.fa-male:before{content:"\f183"}.fa-gittip:before,.fa-gratipay:before{content:"\f184"}.fa-sun-o:before{content:"\f185"}.fa-moon-o:before{content:"\f186"}.fa-archive:before{content:"\f187"}.fa-bug:before{content:"\f188"}.fa-vk:before{content:"\f189"}.fa-weibo:before{content:"\f18a"}.fa-renren:before{content:"\f18b"}.fa-pagelines:before{content:"\f18c"}.fa-stack-exchange:before{content:"\f18d"}.fa-arrow-circle-o-right:before{content:"\f18e"}.fa-arrow-circle-o-left:before{content:"\f190"}.fa-toggle-left:before,.fa-caret-square-o-left:before{content:"\f191"}.fa-dot-circle-o:before{content:"\f192"}.fa-wheelchair:before{content:"\f193"}.fa-vimeo-square:before{content:"\f194"}.fa-turkish-lira:before,.fa-try:before{content:"\f195"}.fa-plus-square-o:before{content:"\f196"}.fa-space-shuttle:before{content:"\f197"}.fa-slack:before{content:"\f198"}.fa-envelope-square:before{content:"\f199"}.fa-wordpress:before{content:"\f19a"}.fa-openid:before{content:"\f19b"}.fa-institution:before,.fa-bank:before,.fa-university:before{content:"\f19c"}.fa-mortar-board:before,.fa-graduation-cap:before{content:"\f19d"}.fa-yahoo:before{content:"\f19e"}.fa-google:before{content:"\f1a0"}.fa-reddit:before{content:"\f1a1"}.fa-reddit-square:before{content:"\f1a2"}.fa-stumbleupon-circle:before{content:"\f1a3"}.fa-stumbleupon:before{content:"\f1a4"}.fa-delicious:before{content:"\f1a5"}.fa-digg:before{content:"\f1a6"}.fa-pied-piper:before{content:"\f1a7"}.fa-pied-piper-alt:before{content:"\f1a8"}.fa-drupal:before{content:"\f1a9"}.fa-joomla:before{content:"\f1aa"}.fa-language:before{content:"\f1ab"}.fa-fax:before{content:"\f1ac"}.fa-building:before{content:"\f1ad"}.fa-child:before{content:"\f1ae"}.fa-paw:before{content:"\f1b0"}.fa-spoon:before{content:"\f1b1"}.fa-cube:before{content:"\f1b2"}.fa-cubes:before{content:"\f1b3"}.fa-behance:before{content:"\f1b4"}.fa-behance-square:before{content:"\f1b5"}.fa-steam:before{content:"\f1b6"}.fa-steam-square:before{content:"\f1b7"}.fa-recycle:before{content:"\f1b8"}.fa-automobile:before,.fa-car:before{content:"\f1b9"}.fa-cab:before,.fa-taxi:before{content:"\f1ba"}.fa-tree:before{content:"\f1bb"}.fa-spotify:before{content:"\f1bc"}.fa-deviantart:before{content:"\f1bd"}.fa-soundcloud:before{content:"\f1be"}.fa-database:before{content:"\f1c0"}.fa-file-pdf-o:before{content:"\f1c1"}.fa-file-word-o:before{content:"\f1c2"}.fa-file-excel-o:before{content:"\f1c3"}.fa-file-powerpoint-o:before{content:"\f1c4"}.fa-file-photo-o:before,.fa-file-picture-o:before,.fa-file-image-o:before{content:"\f1c5"}.fa-file-zip-o:before,.fa-file-archive-o:before{content:"\f1c6"}.fa-file-sound-o:before,.fa-file-audio-o:before{content:"\f1c7"}.fa-file-movie-o:before,.fa-file-video-o:before{content:"\f1c8"}.fa-file-code-o:before{content:"\f1c9"}.fa-vine:before{content:"\f1ca"}.fa-codepen:before{content:"\f1cb"}.fa-jsfiddle:before{content:"\f1cc"}.fa-life-bouy:before,.fa-life-buoy:before,.fa-life-saver:before,.fa-support:before,.fa-life-ring:before{content:"\f1cd"}.fa-circle-o-notch:before{content:"\f1ce"}.fa-ra:before,.fa-rebel:before{content:"\f1d0"}.fa-ge:before,.fa-empire:before{content:"\f1d1"}.fa-git-square:before{content:"\f1d2"}.fa-git:before{content:"\f1d3"}.fa-y-combinator-square:before,.fa-yc-square:before,.fa-hacker-news:before{content:"\f1d4"}.fa-tencent-weibo:before{content:"\f1d5"}.fa-qq:before{content:"\f1d6"}.fa-wechat:before,.fa-weixin:before{content:"\f1d7"}.fa-send:before,.fa-paper-plane:before{content:"\f1d8"}.fa-send-o:before,.fa-paper-plane-o:before{content:"\f1d9"}.fa-history:before{content:"\f1da"}.fa-circle-thin:before{content:"\f1db"}.fa-header:before{content:"\f1dc"}.fa-paragraph:before{content:"\f1dd"}.fa-sliders:before{content:"\f1de"}.fa-share-alt:before{content:"\f1e0"}.fa-share-alt-square:before{content:"\f1e1"}.fa-bomb:before{content:"\f1e2"}.fa-soccer-ball-o:before,.fa-futbol-o:before{content:"\f1e3"}.fa-tty:before{content:"\f1e4"}.fa-binoculars:before{content:"\f1e5"}.fa-plug:before{content:"\f1e6"}.fa-slideshare:before{content:"\f1e7"}.fa-twitch:before{content:"\f1e8"}.fa-yelp:before{content:"\f1e9"}.fa-newspaper-o:before{content:"\f1ea"}.fa-wifi:before{content:"\f1eb"}.fa-calculator:before{content:"\f1ec"}.fa-paypal:before{content:"\f1ed"}.fa-google-wallet:before{content:"\f1ee"}.fa-cc-visa:before{content:"\f1f0"}.fa-cc-mastercard:before{content:"\f1f1"}.fa-cc-discover:before{content:"\f1f2"}.fa-cc-amex:before{content:"\f1f3"}.fa-cc-paypal:before{content:"\f1f4"}.fa-cc-stripe:before{content:"\f1f5"}.fa-bell-slash:before{content:"\f1f6"}.fa-bell-slash-o:before{content:"\f1f7"}.fa-trash:before{content:"\f1f8"}.fa-copyright:before{content:"\f1f9"}.fa-at:before{content:"\f1fa"}.fa-eyedropper:before{content:"\f1fb"}.fa-paint-brush:before{content:"\f1fc"}.fa-birthday-cake:before{content:"\f1fd"}.fa-area-chart:before{content:"\f1fe"}.fa-pie-chart:before{content:"\f200"}.fa-line-chart:before{content:"\f201"}.fa-lastfm:before{content:"\f202"}.fa-lastfm-square:before{content:"\f203"}.fa-toggle-off:before{content:"\f204"}.fa-toggle-on:before{content:"\f205"}.fa-bicycle:before{content:"\f206"}.fa-bus:before{content:"\f207"}.fa-ioxhost:before{content:"\f208"}.fa-angellist:before{content:"\f209"}.fa-cc:before{content:"\f20a"}.fa-shekel:before,.fa-sheqel:before,.fa-ils:before{content:"\f20b"}.fa-meanpath:before{content:"\f20c"}.fa-buysellads:before{content:"\f20d"}.fa-connectdevelop:before{content:"\f20e"}.fa-dashcube:before{content:"\f210"}.fa-forumbee:before{content:"\f211"}.fa-leanpub:before{content:"\f212"}.fa-sellsy:before{content:"\f213"}.fa-shirtsinbulk:before{content:"\f214"}.fa-simplybuilt:before{content:"\f215"}.fa-skyatlas:before{content:"\f216"}.fa-cart-plus:before{content:"\f217"}.fa-cart-arrow-down:before{content:"\f218"}.fa-diamond:before{content:"\f219"}.fa-ship:before{content:"\f21a"}.fa-user-secret:before{content:"\f21b"}.fa-motorcycle:before{content:"\f21c"}.fa-street-view:before{content:"\f21d"}.fa-heartbeat:before{content:"\f21e"}.fa-venus:before{content:"\f221"}.fa-mars:before{content:"\f222"}.fa-mercury:before{content:"\f223"}.fa-intersex:before,.fa-transgender:before{content:"\f224"}.fa-transgender-alt:before{content:"\f225"}.fa-venus-double:before{content:"\f226"}.fa-mars-double:before{content:"\f227"}.fa-venus-mars:before{content:"\f228"}.fa-mars-stroke:before{content:"\f229"}.fa-mars-stroke-v:before{content:"\f22a"}.fa-mars-stroke-h:before{content:"\f22b"}.fa-neuter:before{content:"\f22c"}.fa-genderless:before{content:"\f22d"}.fa-facebook-official:before{content:"\f230"}.fa-pinterest-p:before{content:"\f231"}.fa-whatsapp:before{content:"\f232"}.fa-server:before{content:"\f233"}.fa-user-plus:before{content:"\f234"}.fa-user-times:before{content:"\f235"}.fa-hotel:before,.fa-bed:before{content:"\f236"}.fa-viacoin:before{content:"\f237"}.fa-train:before{content:"\f238"}.fa-subway:before{content:"\f239"}.fa-medium:before{content:"\f23a"}.fa-yc:before,.fa-y-combinator:before{content:"\f23b"}.fa-optin-monster:before{content:"\f23c"}.fa-opencart:before{content:"\f23d"}.fa-expeditedssl:before{content:"\f23e"}.fa-battery-4:before,.fa-battery-full:before{content:"\f240"}.fa-battery-3:before,.fa-battery-three-quarters:before{content:"\f241"}.fa-battery-2:before,.fa-battery-half:before{content:"\f242"}.fa-battery-1:before,.fa-battery-quarter:before{content:"\f243"}.fa-battery-0:before,.fa-battery-empty:before{content:"\f244"}.fa-mouse-pointer:before{content:"\f245"}.fa-i-cursor:before{content:"\f246"}.fa-object-group:before{content:"\f247"}.fa-object-ungroup:before{content:"\f248"}.fa-sticky-note:before{content:"\f249"}.fa-sticky-note-o:before{content:"\f24a"}.fa-cc-jcb:before{content:"\f24b"}.fa-cc-diners-club:before{content:"\f24c"}.fa-clone:before{content:"\f24d"}.fa-balance-scale:before{content:"\f24e"}.fa-hourglass-o:before{content:"\f250"}.fa-hourglass-1:before,.fa-hourglass-start:before{content:"\f251"}.fa-hourglass-2:before,.fa-hourglass-half:before{content:"\f252"}.fa-hourglass-3:before,.fa-hourglass-end:before{content:"\f253"}.fa-hourglass:before{content:"\f254"}.fa-hand-grab-o:before,.fa-hand-rock-o:before{content:"\f255"}.fa-hand-stop-o:before,.fa-hand-paper-o:before{content:"\f256"}.fa-hand-scissors-o:before{content:"\f257"}.fa-hand-lizard-o:before{content:"\f258"}.fa-hand-spock-o:before{content:"\f259"}.fa-hand-pointer-o:before{content:"\f25a"}.fa-hand-peace-o:before{content:"\f25b"}.fa-trademark:before{content:"\f25c"}.fa-registered:before{content:"\f25d"}.fa-creative-commons:before{content:"\f25e"}.fa-gg:before{content:"\f260"}.fa-gg-circle:before{content:"\f261"}.fa-tripadvisor:before{content:"\f262"}.fa-odnoklassniki:before{content:"\f263"}.fa-odnoklassniki-square:before{content:"\f264"}.fa-get-pocket:before{content:"\f265"}.fa-wikipedia-w:before{content:"\f266"}.fa-safari:before{content:"\f267"}.fa-chrome:before{content:"\f268"}.fa-firefox:before{content:"\f269"}.fa-opera:before{content:"\f26a"}.fa-internet-explorer:before{content:"\f26b"}.fa-tv:before,.fa-television:before{content:"\f26c"}.fa-contao:before{content:"\f26d"}.fa-500px:before{content:"\f26e"}.fa-amazon:before{content:"\f270"}.fa-calendar-plus-o:before{content:"\f271"}.fa-calendar-minus-o:before{content:"\f272"}.fa-calendar-times-o:before{content:"\f273"}.fa-calendar-check-o:before{content:"\f274"}.fa-industry:before{content:"\f275"}.fa-map-pin:before{content:"\f276"}.fa-map-signs:before{content:"\f277"}.fa-map-o:before{content:"\f278"}.fa-map:before{content:"\f279"}.fa-commenting:before{content:"\f27a"}.fa-commenting-o:before{content:"\f27b"}.fa-houzz:before{content:"\f27c"}.fa-vimeo:before{content:"\f27d"}.fa-black-tie:before{content:"\f27e"}.fa-fonticons:before{content:"\f280"}.fa-reddit-alien:before{content:"\f281"}.fa-edge:before{content:"\f282"}.fa-credit-card-alt:before{content:"\f283"}.fa-codiepie:before{content:"\f284"}.fa-modx:before{content:"\f285"}.fa-fort-awesome:before{content:"\f286"}.fa-usb:before{content:"\f287"}.fa-product-hunt:before{content:"\f288"}.fa-mixcloud:before{content:"\f289"}.fa-scribd:before{content:"\f28a"}.fa-pause-circle:before{content:"\f28b"}.fa-pause-circle-o:before{content:"\f28c"}.fa-stop-circle:before{content:"\f28d"}.fa-stop-circle-o:before{content:"\f28e"}.fa-shopping-bag:before{content:"\f290"}.fa-shopping-basket:before{content:"\f291"}.fa-hashtag:before{content:"\f292"}.fa-bluetooth:before{content:"\f293"}.fa-bluetooth-b:before{content:"\f294"}.fa-percent:before{content:"\f295"}


/*! jQuery v1.11.1 | (c) 2005, 2014 jQuery Foundation, Inc. | jquery.org/license */
!function(a,b){"object"==typeof module&&"object"==typeof module.exports?module.exports=a.document?b(a,!0):function(a){if(!a.document)throw new Error("jQuery requires a window with a document");return b(a)}:b(a)}("undefined"!=typeof window?window:this,function(a,b){var c=[],d=c.slice,e=c.concat,f=c.push,g=c.indexOf,h={},i=h.toString,j=h.hasOwnProperty,k={},l="1.11.1",m=function(a,b){return new m.fn.init(a,b)},n=/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,o=/^-ms-/,p=/-([\da-z])/gi,q=function(a,b){return b.toUpperCase()};m.fn=m.prototype={jquery:l,constructor:m,selector:"",length:0,toArray:function(){return d.call(this)},get:function(a){return null!=a?0>a?this[a+this.length]:this[a]:d.call(this)},pushStack:function(a){var b=m.merge(this.constructor(),a);return b.prevObject=this,b.context=this.context,b},each:function(a,b){return m.each(this,a,b)},map:function(a){return this.pushStack(m.map(this,function(b,c){return a.call(b,c,b)}))},slice:function(){return this.pushStack(d.apply(this,arguments))},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},eq:function(a){var b=this.length,c=+a+(0>a?b:0);return this.pushStack(c>=0&&b>c?[this[c]]:[])},end:function(){return this.prevObject||this.constructor(null)},push:f,sort:c.sort,splice:c.splice},m.extend=m.fn.extend=function(){var a,b,c,d,e,f,g=arguments[0]||{},h=1,i=arguments.length,j=!1;for("boolean"==typeof g&&(j=g,g=arguments[h]||{},h++),"object"==typeof g||m.isFunction(g)||(g={}),h===i&&(g=this,h--);i>h;h++)if(null!=(e=arguments[h]))for(d in e)a=g[d],c=e[d],g!==c&&(j&&c&&(m.isPlainObject(c)||(b=m.isArray(c)))?(b?(b=!1,f=a&&m.isArray(a)?a:[]):f=a&&m.isPlainObject(a)?a:{},g[d]=m.extend(j,f,c)):void 0!==c&&(g[d]=c));return g},m.extend({expando:"jQuery"+(l+Math.random()).replace(/\D/g,""),isReady:!0,error:function(a){throw new Error(a)},noop:function(){},isFunction:function(a){return"function"===m.type(a)},isArray:Array.isArray||function(a){return"array"===m.type(a)},isWindow:function(a){return null!=a&&a==a.window},isNumeric:function(a){return!m.isArray(a)&&a-parseFloat(a)>=0},isEmptyObject:function(a){var b;for(b in a)return!1;return!0},isPlainObject:function(a){var b;if(!a||"object"!==m.type(a)||a.nodeType||m.isWindow(a))return!1;try{if(a.constructor&&!j.call(a,"constructor")&&!j.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}if(k.ownLast)for(b in a)return j.call(a,b);for(b in a);return void 0===b||j.call(a,b)},type:function(a){return null==a?a+"":"object"==typeof a||"function"==typeof a?h[i.call(a)]||"object":typeof a},globalEval:function(b){b&&m.trim(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(o,"ms-").replace(p,q)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toLowerCase()===b.toLowerCase()},each:function(a,b,c){var d,e=0,f=a.length,g=r(a);if(c){if(g){for(;f>e;e++)if(d=b.apply(a[e],c),d===!1)break}else for(e in a)if(d=b.apply(a[e],c),d===!1)break}else if(g){for(;f>e;e++)if(d=b.call(a[e],e,a[e]),d===!1)break}else for(e in a)if(d=b.call(a[e],e,a[e]),d===!1)break;return a},trim:function(a){return null==a?"":(a+"").replace(n,"")},makeArray:function(a,b){var c=b||[];return null!=a&&(r(Object(a))?m.merge(c,"string"==typeof a?[a]:a):f.call(c,a)),c},inArray:function(a,b,c){var d;if(b){if(g)return g.call(b,a,c);for(d=b.length,c=c?0>c?Math.max(0,d+c):c:0;d>c;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,b){var c=+b.length,d=0,e=a.length;while(c>d)a[e++]=b[d++];if(c!==c)while(void 0!==b[d])a[e++]=b[d++];return a.length=e,a},grep:function(a,b,c){for(var d,e=[],f=0,g=a.length,h=!c;g>f;f++)d=!b(a[f],f),d!==h&&e.push(a[f]);return e},map:function(a,b,c){var d,f=0,g=a.length,h=r(a),i=[];if(h)for(;g>f;f++)d=b(a[f],f,c),null!=d&&i.push(d);else for(f in a)d=b(a[f],f,c),null!=d&&i.push(d);return e.apply([],i)},guid:1,proxy:function(a,b){var c,e,f;return"string"==typeof b&&(f=a[b],b=a,a=f),m.isFunction(a)?(c=d.call(arguments,2),e=function(){return a.apply(b||this,c.concat(d.call(arguments)))},e.guid=a.guid=a.guid||m.guid++,e):void 0},now:function(){return+new Date},support:k}),m.each("Boolean Number String Function Array Date RegExp Object Error".split(" "),function(a,b){h["[object "+b+"]"]=b.toLowerCase()});function r(a){var b=a.length,c=m.type(a);return"function"===c||m.isWindow(a)?!1:1===a.nodeType&&b?!0:"array"===c||0===b||"number"==typeof b&&b>0&&b-1 in a}var s=function(a){var b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u="sizzle"+-new Date,v=a.document,w=0,x=0,y=gb(),z=gb(),A=gb(),B=function(a,b){return a===b&&(l=!0),0},C="undefined",D=1<<31,E={}.hasOwnProperty,F=[],G=F.pop,H=F.push,I=F.push,J=F.slice,K=F.indexOf||function(a){for(var b=0,c=this.length;c>b;b++)if(this[b]===a)return b;return-1},L="checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped",M="[\\x20\\t\\r\\n\\f]",N="(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+",O=N.replace("w","w#"),P="\\["+M+"*("+N+")(?:"+M+"*([*^$|!~]?=)"+M+"*(?:'((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\"|("+O+"))|)"+M+"*\\]",Q=":("+N+")(?:\\((('((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\")|((?:\\\\.|[^\\\\()[\\]]|"+P+")*)|.*)\\)|)",R=new RegExp("^"+M+"+|((?:^|[^\\\\])(?:\\\\.)*)"+M+"+$","g"),S=new RegExp("^"+M+"*,"+M+"*"),T=new RegExp("^"+M+"*([>+~]|"+M+")"+M+"*"),U=new RegExp("="+M+"*([^\\]'\"]*?)"+M+"*\\]","g"),V=new RegExp(Q),W=new RegExp("^"+O+"$"),X={ID:new RegExp("^#("+N+")"),CLASS:new RegExp("^\\.("+N+")"),TAG:new RegExp("^("+N.replace("w","w*")+")"),ATTR:new RegExp("^"+P),PSEUDO:new RegExp("^"+Q),CHILD:new RegExp("^:(only|first|last|nth|nth-last)-(child|of-type)(?:\\("+M+"*(even|odd|(([+-]|)(\\d*)n|)"+M+"*(?:([+-]|)"+M+"*(\\d+)|))"+M+"*\\)|)","i"),bool:new RegExp("^(?:"+L+")$","i"),needsContext:new RegExp("^"+M+"*[>+~]|:(even|odd|eq|gt|lt|nth|first|last)(?:\\("+M+"*((?:-\\d)?\\d*)"+M+"*\\)|)(?=[^-]|$)","i")},Y=/^(?:input|select|textarea|button)$/i,Z=/^h\d$/i,$=/^[^{]+\{\s*\[native \w/,_=/^(?:#([\w-]+)|(\w+)|\.([\w-]+))$/,ab=/[+~]/,bb=/'|\\/g,cb=new RegExp("\\\\([\\da-f]{1,6}"+M+"?|("+M+")|.)","ig"),db=function(a,b,c){var d="0x"+b-65536;return d!==d||c?b:0>d?String.fromCharCode(d+65536):String.fromCharCode(d>>10|55296,1023&d|56320)};try{I.apply(F=J.call(v.childNodes),v.childNodes),F[v.childNodes.length].nodeType}catch(eb){I={apply:F.length?function(a,b){H.apply(a,J.call(b))}:function(a,b){var c=a.length,d=0;while(a[c++]=b[d++]);a.length=c-1}}}function fb(a,b,d,e){var f,h,j,k,l,o,r,s,w,x;if((b?b.ownerDocument||b:v)!==n&&m(b),b=b||n,d=d||[],!a||"string"!=typeof a)return d;if(1!==(k=b.nodeType)&&9!==k)return[];if(p&&!e){if(f=_.exec(a))if(j=f[1]){if(9===k){if(h=b.getElementById(j),!h||!h.parentNode)return d;if(h.id===j)return d.push(h),d}else if(b.ownerDocument&&(h=b.ownerDocument.getElementById(j))&&t(b,h)&&h.id===j)return d.push(h),d}else{if(f[2])return I.apply(d,b.getElementsByTagName(a)),d;if((j=f[3])&&c.getElementsByClassName&&b.getElementsByClassName)return I.apply(d,b.getElementsByClassName(j)),d}if(c.qsa&&(!q||!q.test(a))){if(s=r=u,w=b,x=9===k&&a,1===k&&"object"!==b.nodeName.toLowerCase()){o=g(a),(r=b.getAttribute("id"))?s=r.replace(bb,"\\$&"):b.setAttribute("id",s),s="[id='"+s+"'] ",l=o.length;while(l--)o[l]=s+qb(o[l]);w=ab.test(a)&&ob(b.parentNode)||b,x=o.join(",")}if(x)try{return I.apply(d,w.querySelectorAll(x)),d}catch(y){}finally{r||b.removeAttribute("id")}}}return i(a.replace(R,"$1"),b,d,e)}function gb(){var a=[];function b(c,e){return a.push(c+" ")>d.cacheLength&&delete b[a.shift()],b[c+" "]=e}return b}function hb(a){return a[u]=!0,a}function ib(a){var b=n.createElement("div");try{return!!a(b)}catch(c){return!1}finally{b.parentNode&&b.parentNode.removeChild(b),b=null}}function jb(a,b){var c=a.split("|"),e=a.length;while(e--)d.attrHandle[c[e]]=b}function kb(a,b){var c=b&&a,d=c&&1===a.nodeType&&1===b.nodeType&&(~b.sourceIndex||D)-(~a.sourceIndex||D);if(d)return d;if(c)while(c=c.nextSibling)if(c===b)return-1;return a?1:-1}function lb(a){return function(b){var c=b.nodeName.toLowerCase();return"input"===c&&b.type===a}}function mb(a){return function(b){var c=b.nodeName.toLowerCase();return("input"===c||"button"===c)&&b.type===a}}function nb(a){return hb(function(b){return b=+b,hb(function(c,d){var e,f=a([],c.length,b),g=f.length;while(g--)c[e=f[g]]&&(c[e]=!(d[e]=c[e]))})})}function ob(a){return a&&typeof a.getElementsByTagName!==C&&a}c=fb.support={},f=fb.isXML=function(a){var b=a&&(a.ownerDocument||a).documentElement;return b?"HTML"!==b.nodeName:!1},m=fb.setDocument=function(a){var b,e=a?a.ownerDocument||a:v,g=e.defaultView;return e!==n&&9===e.nodeType&&e.documentElement?(n=e,o=e.documentElement,p=!f(e),g&&g!==g.top&&(g.addEventListener?g.addEventListener("unload",function(){m()},!1):g.attachEvent&&g.attachEvent("onunload",function(){m()})),c.attributes=ib(function(a){return a.className="i",!a.getAttribute("className")}),c.getElementsByTagName=ib(function(a){return a.appendChild(e.createComment("")),!a.getElementsByTagName("*").length}),c.getElementsByClassName=$.test(e.getElementsByClassName)&&ib(function(a){return a.innerHTML="<div class='a'></div><div class='a i'></div>",a.firstChild.className="i",2===a.getElementsByClassName("i").length}),c.getById=ib(function(a){return o.appendChild(a).id=u,!e.getElementsByName||!e.getElementsByName(u).length}),c.getById?(d.find.ID=function(a,b){if(typeof b.getElementById!==C&&p){var c=b.getElementById(a);return c&&c.parentNode?[c]:[]}},d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){return a.getAttribute("id")===b}}):(delete d.find.ID,d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){var c=typeof a.getAttributeNode!==C&&a.getAttributeNode("id");return c&&c.value===b}}),d.find.TAG=c.getElementsByTagName?function(a,b){return typeof b.getElementsByTagName!==C?b.getElementsByTagName(a):void 0}:function(a,b){var c,d=[],e=0,f=b.getElementsByTagName(a);if("*"===a){while(c=f[e++])1===c.nodeType&&d.push(c);return d}return f},d.find.CLASS=c.getElementsByClassName&&function(a,b){return typeof b.getElementsByClassName!==C&&p?b.getElementsByClassName(a):void 0},r=[],q=[],(c.qsa=$.test(e.querySelectorAll))&&(ib(function(a){a.innerHTML="<select msallowclip=''><option selected=''></option></select>",a.querySelectorAll("[msallowclip^='']").length&&q.push("[*^$]="+M+"*(?:''|\"\")"),a.querySelectorAll("[selected]").length||q.push("\\["+M+"*(?:value|"+L+")"),a.querySelectorAll(":checked").length||q.push(":checked")}),ib(function(a){var b=e.createElement("input");b.setAttribute("type","hidden"),a.appendChild(b).setAttribute("name","D"),a.querySelectorAll("[name=d]").length&&q.push("name"+M+"*[*^$|!~]?="),a.querySelectorAll(":enabled").length||q.push(":enabled",":disabled"),a.querySelectorAll("*,:x"),q.push(",.*:")})),(c.matchesSelector=$.test(s=o.matches||o.webkitMatchesSelector||o.mozMatchesSelector||o.oMatchesSelector||o.msMatchesSelector))&&ib(function(a){c.disconnectedMatch=s.call(a,"div"),s.call(a,"[s!='']:x"),r.push("!=",Q)}),q=q.length&&new RegExp(q.join("|")),r=r.length&&new RegExp(r.join("|")),b=$.test(o.compareDocumentPosition),t=b||$.test(o.contains)?function(a,b){var c=9===a.nodeType?a.documentElement:a,d=b&&b.parentNode;return a===d||!(!d||1!==d.nodeType||!(c.contains?c.contains(d):a.compareDocumentPosition&&16&a.compareDocumentPosition(d)))}:function(a,b){if(b)while(b=b.parentNode)if(b===a)return!0;return!1},B=b?function(a,b){if(a===b)return l=!0,0;var d=!a.compareDocumentPosition-!b.compareDocumentPosition;return d?d:(d=(a.ownerDocument||a)===(b.ownerDocument||b)?a.compareDocumentPosition(b):1,1&d||!c.sortDetached&&b.compareDocumentPosition(a)===d?a===e||a.ownerDocument===v&&t(v,a)?-1:b===e||b.ownerDocument===v&&t(v,b)?1:k?K.call(k,a)-K.call(k,b):0:4&d?-1:1)}:function(a,b){if(a===b)return l=!0,0;var c,d=0,f=a.parentNode,g=b.parentNode,h=[a],i=[b];if(!f||!g)return a===e?-1:b===e?1:f?-1:g?1:k?K.call(k,a)-K.call(k,b):0;if(f===g)return kb(a,b);c=a;while(c=c.parentNode)h.unshift(c);c=b;while(c=c.parentNode)i.unshift(c);while(h[d]===i[d])d++;return d?kb(h[d],i[d]):h[d]===v?-1:i[d]===v?1:0},e):n},fb.matches=function(a,b){return fb(a,null,null,b)},fb.matchesSelector=function(a,b){if((a.ownerDocument||a)!==n&&m(a),b=b.replace(U,"='$1']"),!(!c.matchesSelector||!p||r&&r.test(b)||q&&q.test(b)))try{var d=s.call(a,b);if(d||c.disconnectedMatch||a.document&&11!==a.document.nodeType)return d}catch(e){}return fb(b,n,null,[a]).length>0},fb.contains=function(a,b){return(a.ownerDocument||a)!==n&&m(a),t(a,b)},fb.attr=function(a,b){(a.ownerDocument||a)!==n&&m(a);var e=d.attrHandle[b.toLowerCase()],f=e&&E.call(d.attrHandle,b.toLowerCase())?e(a,b,!p):void 0;return void 0!==f?f:c.attributes||!p?a.getAttribute(b):(f=a.getAttributeNode(b))&&f.specified?f.value:null},fb.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)},fb.uniqueSort=function(a){var b,d=[],e=0,f=0;if(l=!c.detectDuplicates,k=!c.sortStable&&a.slice(0),a.sort(B),l){while(b=a[f++])b===a[f]&&(e=d.push(f));while(e--)a.splice(d[e],1)}return k=null,a},e=fb.getText=function(a){var b,c="",d=0,f=a.nodeType;if(f){if(1===f||9===f||11===f){if("string"==typeof a.textContent)return a.textContent;for(a=a.firstChild;a;a=a.nextSibling)c+=e(a)}else if(3===f||4===f)return a.nodeValue}else while(b=a[d++])c+=e(b);return c},d=fb.selectors={cacheLength:50,createPseudo:hb,match:X,attrHandle:{},find:{},relative:{">":{dir:"parentNode",first:!0}," ":{dir:"parentNode"},"+":{dir:"previousSibling",first:!0},"~":{dir:"previousSibling"}},preFilter:{ATTR:function(a){return a[1]=a[1].replace(cb,db),a[3]=(a[3]||a[4]||a[5]||"").replace(cb,db),"~="===a[2]&&(a[3]=" "+a[3]+" "),a.slice(0,4)},CHILD:function(a){return a[1]=a[1].toLowerCase(),"nth"===a[1].slice(0,3)?(a[3]||fb.error(a[0]),a[4]=+(a[4]?a[5]+(a[6]||1):2*("even"===a[3]||"odd"===a[3])),a[5]=+(a[7]+a[8]||"odd"===a[3])):a[3]&&fb.error(a[0]),a},PSEUDO:function(a){var b,c=!a[6]&&a[2];return X.CHILD.test(a[0])?null:(a[3]?a[2]=a[4]||a[5]||"":c&&V.test(c)&&(b=g(c,!0))&&(b=c.indexOf(")",c.length-b)-c.length)&&(a[0]=a[0].slice(0,b),a[2]=c.slice(0,b)),a.slice(0,3))}},filter:{TAG:function(a){var b=a.replace(cb,db).toLowerCase();return"*"===a?function(){return!0}:function(a){return a.nodeName&&a.nodeName.toLowerCase()===b}},CLASS:function(a){var b=y[a+" "];return b||(b=new RegExp("(^|"+M+")"+a+"("+M+"|$)"))&&y(a,function(a){return b.test("string"==typeof a.className&&a.className||typeof a.getAttribute!==C&&a.getAttribute("class")||"")})},ATTR:function(a,b,c){return function(d){var e=fb.attr(d,a);return null==e?"!="===b:b?(e+="","="===b?e===c:"!="===b?e!==c:"^="===b?c&&0===e.indexOf(c):"*="===b?c&&e.indexOf(c)>-1:"$="===b?c&&e.slice(-c.length)===c:"~="===b?(" "+e+" ").indexOf(c)>-1:"|="===b?e===c||e.slice(0,c.length+1)===c+"-":!1):!0}},CHILD:function(a,b,c,d,e){var f="nth"!==a.slice(0,3),g="last"!==a.slice(-4),h="of-type"===b;return 1===d&&0===e?function(a){return!!a.parentNode}:function(b,c,i){var j,k,l,m,n,o,p=f!==g?"nextSibling":"previousSibling",q=b.parentNode,r=h&&b.nodeName.toLowerCase(),s=!i&&!h;if(q){if(f){while(p){l=b;while(l=l[p])if(h?l.nodeName.toLowerCase()===r:1===l.nodeType)return!1;o=p="only"===a&&!o&&"nextSibling"}return!0}if(o=[g?q.firstChild:q.lastChild],g&&s){k=q[u]||(q[u]={}),j=k[a]||[],n=j[0]===w&&j[1],m=j[0]===w&&j[2],l=n&&q.childNodes[n];while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if(1===l.nodeType&&++m&&l===b){k[a]=[w,n,m];break}}else if(s&&(j=(b[u]||(b[u]={}))[a])&&j[0]===w)m=j[1];else while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if((h?l.nodeName.toLowerCase()===r:1===l.nodeType)&&++m&&(s&&((l[u]||(l[u]={}))[a]=[w,m]),l===b))break;return m-=e,m===d||m%d===0&&m/d>=0}}},PSEUDO:function(a,b){var c,e=d.pseudos[a]||d.setFilters[a.toLowerCase()]||fb.error("unsupported pseudo: "+a);return e[u]?e(b):e.length>1?(c=[a,a,"",b],d.setFilters.hasOwnProperty(a.toLowerCase())?hb(function(a,c){var d,f=e(a,b),g=f.length;while(g--)d=K.call(a,f[g]),a[d]=!(c[d]=f[g])}):function(a){return e(a,0,c)}):e}},pseudos:{not:hb(function(a){var b=[],c=[],d=h(a.replace(R,"$1"));return d[u]?hb(function(a,b,c,e){var f,g=d(a,null,e,[]),h=a.length;while(h--)(f=g[h])&&(a[h]=!(b[h]=f))}):function(a,e,f){return b[0]=a,d(b,null,f,c),!c.pop()}}),has:hb(function(a){return function(b){return fb(a,b).length>0}}),contains:hb(function(a){return function(b){return(b.textContent||b.innerText||e(b)).indexOf(a)>-1}}),lang:hb(function(a){return W.test(a||"")||fb.error("unsupported lang: "+a),a=a.replace(cb,db).toLowerCase(),function(b){var c;do if(c=p?b.lang:b.getAttribute("xml:lang")||b.getAttribute("lang"))return c=c.toLowerCase(),c===a||0===c.indexOf(a+"-");while((b=b.parentNode)&&1===b.nodeType);return!1}}),target:function(b){var c=a.location&&a.location.hash;return c&&c.slice(1)===b.id},root:function(a){return a===o},focus:function(a){return a===n.activeElement&&(!n.hasFocus||n.hasFocus())&&!!(a.type||a.href||~a.tabIndex)},enabled:function(a){return a.disabled===!1},disabled:function(a){return a.disabled===!0},checked:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&!!a.checked||"option"===b&&!!a.selected},selected:function(a){return a.parentNode&&a.parentNode.selectedIndex,a.selected===!0},empty:function(a){for(a=a.firstChild;a;a=a.nextSibling)if(a.nodeType<6)return!1;return!0},parent:function(a){return!d.pseudos.empty(a)},header:function(a){return Z.test(a.nodeName)},input:function(a){return Y.test(a.nodeName)},button:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&"button"===a.type||"button"===b},text:function(a){var b;return"input"===a.nodeName.toLowerCase()&&"text"===a.type&&(null==(b=a.getAttribute("type"))||"text"===b.toLowerCase())},first:nb(function(){return[0]}),last:nb(function(a,b){return[b-1]}),eq:nb(function(a,b,c){return[0>c?c+b:c]}),even:nb(function(a,b){for(var c=0;b>c;c+=2)a.push(c);return a}),odd:nb(function(a,b){for(var c=1;b>c;c+=2)a.push(c);return a}),lt:nb(function(a,b,c){for(var d=0>c?c+b:c;--d>=0;)a.push(d);return a}),gt:nb(function(a,b,c){for(var d=0>c?c+b:c;++d<b;)a.push(d);return a})}},d.pseudos.nth=d.pseudos.eq;for(b in{radio:!0,checkbox:!0,file:!0,password:!0,image:!0})d.pseudos[b]=lb(b);for(b in{submit:!0,reset:!0})d.pseudos[b]=mb(b);function pb(){}pb.prototype=d.filters=d.pseudos,d.setFilters=new pb,g=fb.tokenize=function(a,b){var c,e,f,g,h,i,j,k=z[a+" "];if(k)return b?0:k.slice(0);h=a,i=[],j=d.preFilter;while(h){(!c||(e=S.exec(h)))&&(e&&(h=h.slice(e[0].length)||h),i.push(f=[])),c=!1,(e=T.exec(h))&&(c=e.shift(),f.push({value:c,type:e[0].replace(R," ")}),h=h.slice(c.length));for(g in d.filter)!(e=X[g].exec(h))||j[g]&&!(e=j[g](e))||(c=e.shift(),f.push({value:c,type:g,matches:e}),h=h.slice(c.length));if(!c)break}return b?h.length:h?fb.error(a):z(a,i).slice(0)};function qb(a){for(var b=0,c=a.length,d="";c>b;b++)d+=a[b].value;return d}function rb(a,b,c){var d=b.dir,e=c&&"parentNode"===d,f=x++;return b.first?function(b,c,f){while(b=b[d])if(1===b.nodeType||e)return a(b,c,f)}:function(b,c,g){var h,i,j=[w,f];if(g){while(b=b[d])if((1===b.nodeType||e)&&a(b,c,g))return!0}else while(b=b[d])if(1===b.nodeType||e){if(i=b[u]||(b[u]={}),(h=i[d])&&h[0]===w&&h[1]===f)return j[2]=h[2];if(i[d]=j,j[2]=a(b,c,g))return!0}}}function sb(a){return a.length>1?function(b,c,d){var e=a.length;while(e--)if(!a[e](b,c,d))return!1;return!0}:a[0]}function tb(a,b,c){for(var d=0,e=b.length;e>d;d++)fb(a,b[d],c);return c}function ub(a,b,c,d,e){for(var f,g=[],h=0,i=a.length,j=null!=b;i>h;h++)(f=a[h])&&(!c||c(f,d,e))&&(g.push(f),j&&b.push(h));return g}function vb(a,b,c,d,e,f){return d&&!d[u]&&(d=vb(d)),e&&!e[u]&&(e=vb(e,f)),hb(function(f,g,h,i){var j,k,l,m=[],n=[],o=g.length,p=f||tb(b||"*",h.nodeType?[h]:h,[]),q=!a||!f&&b?p:ub(p,m,a,h,i),r=c?e||(f?a:o||d)?[]:g:q;if(c&&c(q,r,h,i),d){j=ub(r,n),d(j,[],h,i),k=j.length;while(k--)(l=j[k])&&(r[n[k]]=!(q[n[k]]=l))}if(f){if(e||a){if(e){j=[],k=r.length;while(k--)(l=r[k])&&j.push(q[k]=l);e(null,r=[],j,i)}k=r.length;while(k--)(l=r[k])&&(j=e?K.call(f,l):m[k])>-1&&(f[j]=!(g[j]=l))}}else r=ub(r===g?r.splice(o,r.length):r),e?e(null,g,r,i):I.apply(g,r)})}function wb(a){for(var b,c,e,f=a.length,g=d.relative[a[0].type],h=g||d.relative[" "],i=g?1:0,k=rb(function(a){return a===b},h,!0),l=rb(function(a){return K.call(b,a)>-1},h,!0),m=[function(a,c,d){return!g&&(d||c!==j)||((b=c).nodeType?k(a,c,d):l(a,c,d))}];f>i;i++)if(c=d.relative[a[i].type])m=[rb(sb(m),c)];else{if(c=d.filter[a[i].type].apply(null,a[i].matches),c[u]){for(e=++i;f>e;e++)if(d.relative[a[e].type])break;return vb(i>1&&sb(m),i>1&&qb(a.slice(0,i-1).concat({value:" "===a[i-2].type?"*":""})).replace(R,"$1"),c,e>i&&wb(a.slice(i,e)),f>e&&wb(a=a.slice(e)),f>e&&qb(a))}m.push(c)}return sb(m)}function xb(a,b){var c=b.length>0,e=a.length>0,f=function(f,g,h,i,k){var l,m,o,p=0,q="0",r=f&&[],s=[],t=j,u=f||e&&d.find.TAG("*",k),v=w+=null==t?1:Math.random()||.1,x=u.length;for(k&&(j=g!==n&&g);q!==x&&null!=(l=u[q]);q++){if(e&&l){m=0;while(o=a[m++])if(o(l,g,h)){i.push(l);break}k&&(w=v)}c&&((l=!o&&l)&&p--,f&&r.push(l))}if(p+=q,c&&q!==p){m=0;while(o=b[m++])o(r,s,g,h);if(f){if(p>0)while(q--)r[q]||s[q]||(s[q]=G.call(i));s=ub(s)}I.apply(i,s),k&&!f&&s.length>0&&p+b.length>1&&fb.uniqueSort(i)}return k&&(w=v,j=t),r};return c?hb(f):f}return h=fb.compile=function(a,b){var c,d=[],e=[],f=A[a+" "];if(!f){b||(b=g(a)),c=b.length;while(c--)f=wb(b[c]),f[u]?d.push(f):e.push(f);f=A(a,xb(e,d)),f.selector=a}return f},i=fb.select=function(a,b,e,f){var i,j,k,l,m,n="function"==typeof a&&a,o=!f&&g(a=n.selector||a);if(e=e||[],1===o.length){if(j=o[0]=o[0].slice(0),j.length>2&&"ID"===(k=j[0]).type&&c.getById&&9===b.nodeType&&p&&d.relative[j[1].type]){if(b=(d.find.ID(k.matches[0].replace(cb,db),b)||[])[0],!b)return e;n&&(b=b.parentNode),a=a.slice(j.shift().value.length)}i=X.needsContext.test(a)?0:j.length;while(i--){if(k=j[i],d.relative[l=k.type])break;if((m=d.find[l])&&(f=m(k.matches[0].replace(cb,db),ab.test(j[0].type)&&ob(b.parentNode)||b))){if(j.splice(i,1),a=f.length&&qb(j),!a)return I.apply(e,f),e;break}}}return(n||h(a,o))(f,b,!p,e,ab.test(a)&&ob(b.parentNode)||b),e},c.sortStable=u.split("").sort(B).join("")===u,c.detectDuplicates=!!l,m(),c.sortDetached=ib(function(a){return 1&a.compareDocumentPosition(n.createElement("div"))}),ib(function(a){return a.innerHTML="<a href='#'></a>","#"===a.firstChild.getAttribute("href")})||jb("type|href|height|width",function(a,b,c){return c?void 0:a.getAttribute(b,"type"===b.toLowerCase()?1:2)}),c.attributes&&ib(function(a){return a.innerHTML="<input/>",a.firstChild.setAttribute("value",""),""===a.firstChild.getAttribute("value")})||jb("value",function(a,b,c){return c||"input"!==a.nodeName.toLowerCase()?void 0:a.defaultValue}),ib(function(a){return null==a.getAttribute("disabled")})||jb(L,function(a,b,c){var d;return c?void 0:a[b]===!0?b.toLowerCase():(d=a.getAttributeNode(b))&&d.specified?d.value:null}),fb}(a);m.find=s,m.expr=s.selectors,m.expr[":"]=m.expr.pseudos,m.unique=s.uniqueSort,m.text=s.getText,m.isXMLDoc=s.isXML,m.contains=s.contains;var t=m.expr.match.needsContext,u=/^<(\w+)\s*\/?>(?:<\/\1>|)$/,v=/^.[^:#\[\.,]*$/;function w(a,b,c){if(m.isFunction(b))return m.grep(a,function(a,d){return!!b.call(a,d,a)!==c});if(b.nodeType)return m.grep(a,function(a){return a===b!==c});if("string"==typeof b){if(v.test(b))return m.filter(b,a,c);b=m.filter(b,a)}return m.grep(a,function(a){return m.inArray(a,b)>=0!==c})}m.filter=function(a,b,c){var d=b[0];return c&&(a=":not("+a+")"),1===b.length&&1===d.nodeType?m.find.matchesSelector(d,a)?[d]:[]:m.find.matches(a,m.grep(b,function(a){return 1===a.nodeType}))},m.fn.extend({find:function(a){var b,c=[],d=this,e=d.length;if("string"!=typeof a)return this.pushStack(m(a).filter(function(){for(b=0;e>b;b++)if(m.contains(d[b],this))return!0}));for(b=0;e>b;b++)m.find(a,d[b],c);return c=this.pushStack(e>1?m.unique(c):c),c.selector=this.selector?this.selector+" "+a:a,c},filter:function(a){return this.pushStack(w(this,a||[],!1))},not:function(a){return this.pushStack(w(this,a||[],!0))},is:function(a){return!!w(this,"string"==typeof a&&t.test(a)?m(a):a||[],!1).length}});var x,y=a.document,z=/^(?:\s*(<[\w\W]+>)[^>]*|#([\w-]*))$/,A=m.fn.init=function(a,b){var c,d;if(!a)return this;if("string"==typeof a){if(c="<"===a.charAt(0)&&">"===a.charAt(a.length-1)&&a.length>=3?[null,a,null]:z.exec(a),!c||!c[1]&&b)return!b||b.jquery?(b||x).find(a):this.constructor(b).find(a);if(c[1]){if(b=b instanceof m?b[0]:b,m.merge(this,m.parseHTML(c[1],b&&b.nodeType?b.ownerDocument||b:y,!0)),u.test(c[1])&&m.isPlainObject(b))for(c in b)m.isFunction(this[c])?this[c](b[c]):this.attr(c,b[c]);return this}if(d=y.getElementById(c[2]),d&&d.parentNode){if(d.id!==c[2])return x.find(a);this.length=1,this[0]=d}return this.context=y,this.selector=a,this}return a.nodeType?(this.context=this[0]=a,this.length=1,this):m.isFunction(a)?"undefined"!=typeof x.ready?x.ready(a):a(m):(void 0!==a.selector&&(this.selector=a.selector,this.context=a.context),m.makeArray(a,this))};A.prototype=m.fn,x=m(y);var B=/^(?:parents|prev(?:Until|All))/,C={children:!0,contents:!0,next:!0,prev:!0};m.extend({dir:function(a,b,c){var d=[],e=a[b];while(e&&9!==e.nodeType&&(void 0===c||1!==e.nodeType||!m(e).is(c)))1===e.nodeType&&d.push(e),e=e[b];return d},sibling:function(a,b){for(var c=[];a;a=a.nextSibling)1===a.nodeType&&a!==b&&c.push(a);return c}}),m.fn.extend({has:function(a){var b,c=m(a,this),d=c.length;return this.filter(function(){for(b=0;d>b;b++)if(m.contains(this,c[b]))return!0})},closest:function(a,b){for(var c,d=0,e=this.length,f=[],g=t.test(a)||"string"!=typeof a?m(a,b||this.context):0;e>d;d++)for(c=this[d];c&&c!==b;c=c.parentNode)if(c.nodeType<11&&(g?g.index(c)>-1:1===c.nodeType&&m.find.matchesSelector(c,a))){f.push(c);break}return this.pushStack(f.length>1?m.unique(f):f)},index:function(a){return a?"string"==typeof a?m.inArray(this[0],m(a)):m.inArray(a.jquery?a[0]:a,this):this[0]&&this[0].parentNode?this.first().prevAll().length:-1},add:function(a,b){return this.pushStack(m.unique(m.merge(this.get(),m(a,b))))},addBack:function(a){return this.add(null==a?this.prevObject:this.prevObject.filter(a))}});function D(a,b){do a=a[b];while(a&&1!==a.nodeType);return a}m.each({parent:function(a){var b=a.parentNode;return b&&11!==b.nodeType?b:null},parents:function(a){return m.dir(a,"parentNode")},parentsUntil:function(a,b,c){return m.dir(a,"parentNode",c)},next:function(a){return D(a,"nextSibling")},prev:function(a){return D(a,"previousSibling")},nextAll:function(a){return m.dir(a,"nextSibling")},prevAll:function(a){return m.dir(a,"previousSibling")},nextUntil:function(a,b,c){return m.dir(a,"nextSibling",c)},prevUntil:function(a,b,c){return m.dir(a,"previousSibling",c)},siblings:function(a){return m.sibling((a.parentNode||{}).firstChild,a)},children:function(a){return m.sibling(a.firstChild)},contents:function(a){return m.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:m.merge([],a.childNodes)}},function(a,b){m.fn[a]=function(c,d){var e=m.map(this,b,c);return"Until"!==a.slice(-5)&&(d=c),d&&"string"==typeof d&&(e=m.filter(d,e)),this.length>1&&(C[a]||(e=m.unique(e)),B.test(a)&&(e=e.reverse())),this.pushStack(e)}});var E=/\S+/g,F={};function G(a){var b=F[a]={};return m.each(a.match(E)||[],function(a,c){b[c]=!0}),b}m.Callbacks=function(a){a="string"==typeof a?F[a]||G(a):m.extend({},a);var b,c,d,e,f,g,h=[],i=!a.once&&[],j=function(l){for(c=a.memory&&l,d=!0,f=g||0,g=0,e=h.length,b=!0;h&&e>f;f++)if(h[f].apply(l[0],l[1])===!1&&a.stopOnFalse){c=!1;break}b=!1,h&&(i?i.length&&j(i.shift()):c?h=[]:k.disable())},k={add:function(){if(h){var d=h.length;!function f(b){m.each(b,function(b,c){var d=m.type(c);"function"===d?a.unique&&k.has(c)||h.push(c):c&&c.length&&"string"!==d&&f(c)})}(arguments),b?e=h.length:c&&(g=d,j(c))}return this},remove:function(){return h&&m.each(arguments,function(a,c){var d;while((d=m.inArray(c,h,d))>-1)h.splice(d,1),b&&(e>=d&&e--,f>=d&&f--)}),this},has:function(a){return a?m.inArray(a,h)>-1:!(!h||!h.length)},empty:function(){return h=[],e=0,this},disable:function(){return h=i=c=void 0,this},disabled:function(){return!h},lock:function(){return i=void 0,c||k.disable(),this},locked:function(){return!i},fireWith:function(a,c){return!h||d&&!i||(c=c||[],c=[a,c.slice?c.slice():c],b?i.push(c):j(c)),this},fire:function(){return k.fireWith(this,arguments),this},fired:function(){return!!d}};return k},m.extend({Deferred:function(a){var b=[["resolve","done",m.Callbacks("once memory"),"resolved"],["reject","fail",m.Callbacks("once memory"),"rejected"],["notify","progress",m.Callbacks("memory")]],c="pending",d={state:function(){return c},always:function(){return e.done(arguments).fail(arguments),this},then:function(){var a=arguments;return m.Deferred(function(c){m.each(b,function(b,f){var g=m.isFunction(a[b])&&a[b];e[f[1]](function(){var a=g&&g.apply(this,arguments);a&&m.isFunction(a.promise)?a.promise().done(c.resolve).fail(c.reject).progress(c.notify):c[f[0]+"With"](this===d?c.promise():this,g?[a]:arguments)})}),a=null}).promise()},promise:function(a){return null!=a?m.extend(a,d):d}},e={};return d.pipe=d.then,m.each(b,function(a,f){var g=f[2],h=f[3];d[f[1]]=g.add,h&&g.add(function(){c=h},b[1^a][2].disable,b[2][2].lock),e[f[0]]=function(){return e[f[0]+"With"](this===e?d:this,arguments),this},e[f[0]+"With"]=g.fireWith}),d.promise(e),a&&a.call(e,e),e},when:function(a){var b=0,c=d.call(arguments),e=c.length,f=1!==e||a&&m.isFunction(a.promise)?e:0,g=1===f?a:m.Deferred(),h=function(a,b,c){return function(e){b[a]=this,c[a]=arguments.length>1?d.call(arguments):e,c===i?g.notifyWith(b,c):--f||g.resolveWith(b,c)}},i,j,k;if(e>1)for(i=new Array(e),j=new Array(e),k=new Array(e);e>b;b++)c[b]&&m.isFunction(c[b].promise)?c[b].promise().done(h(b,k,c)).fail(g.reject).progress(h(b,j,i)):--f;return f||g.resolveWith(k,c),g.promise()}});var H;m.fn.ready=function(a){return m.ready.promise().done(a),this},m.extend({isReady:!1,readyWait:1,holdReady:function(a){a?m.readyWait++:m.ready(!0)},ready:function(a){if(a===!0?!--m.readyWait:!m.isReady){if(!y.body)return setTimeout(m.ready);m.isReady=!0,a!==!0&&--m.readyWait>0||(H.resolveWith(y,[m]),m.fn.triggerHandler&&(m(y).triggerHandler("ready"),m(y).off("ready")))}}});function I(){y.addEventListener?(y.removeEventListener("DOMContentLoaded",J,!1),a.removeEventListener("load",J,!1)):(y.detachEvent("onreadystatechange",J),a.detachEvent("onload",J))}function J(){(y.addEventListener||"load"===event.type||"complete"===y.readyState)&&(I(),m.ready())}m.ready.promise=function(b){if(!H)if(H=m.Deferred(),"complete"===y.readyState)setTimeout(m.ready);else if(y.addEventListener)y.addEventListener("DOMContentLoaded",J,!1),a.addEventListener("load",J,!1);else{y.attachEvent("onreadystatechange",J),a.attachEvent("onload",J);var c=!1;try{c=null==a.frameElement&&y.documentElement}catch(d){}c&&c.doScroll&&!function e(){if(!m.isReady){try{c.doScroll("left")}catch(a){return setTimeout(e,50)}I(),m.ready()}}()}return H.promise(b)};var K="undefined",L;for(L in m(k))break;k.ownLast="0"!==L,k.inlineBlockNeedsLayout=!1,m(function(){var a,b,c,d;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="display:inline;margin:0;border:0;padding:1px;width:1px;zoom:1",k.inlineBlockNeedsLayout=a=3===b.offsetWidth,a&&(c.style.zoom=1)),c.removeChild(d))}),function(){var a=y.createElement("div");if(null==k.deleteExpando){k.deleteExpando=!0;try{delete a.test}catch(b){k.deleteExpando=!1}}a=null}(),m.acceptData=function(a){var b=m.noData[(a.nodeName+" ").toLowerCase()],c=+a.nodeType||1;return 1!==c&&9!==c?!1:!b||b!==!0&&a.getAttribute("classid")===b};var M=/^(?:\{[\w\W]*\}|\[[\w\W]*\])$/,N=/([A-Z])/g;function O(a,b,c){if(void 0===c&&1===a.nodeType){var d="data-"+b.replace(N,"-$1").toLowerCase();if(c=a.getAttribute(d),"string"==typeof c){try{c="true"===c?!0:"false"===c?!1:"null"===c?null:+c+""===c?+c:M.test(c)?m.parseJSON(c):c}catch(e){}m.data(a,b,c)}else c=void 0}return c}function P(a){var b;for(b in a)if(("data"!==b||!m.isEmptyObject(a[b]))&&"toJSON"!==b)return!1;return!0}function Q(a,b,d,e){if(m.acceptData(a)){var f,g,h=m.expando,i=a.nodeType,j=i?m.cache:a,k=i?a[h]:a[h]&&h;
if(k&&j[k]&&(e||j[k].data)||void 0!==d||"string"!=typeof b)return k||(k=i?a[h]=c.pop()||m.guid++:h),j[k]||(j[k]=i?{}:{toJSON:m.noop}),("object"==typeof b||"function"==typeof b)&&(e?j[k]=m.extend(j[k],b):j[k].data=m.extend(j[k].data,b)),g=j[k],e||(g.data||(g.data={}),g=g.data),void 0!==d&&(g[m.camelCase(b)]=d),"string"==typeof b?(f=g[b],null==f&&(f=g[m.camelCase(b)])):f=g,f}}function R(a,b,c){if(m.acceptData(a)){var d,e,f=a.nodeType,g=f?m.cache:a,h=f?a[m.expando]:m.expando;if(g[h]){if(b&&(d=c?g[h]:g[h].data)){m.isArray(b)?b=b.concat(m.map(b,m.camelCase)):b in d?b=[b]:(b=m.camelCase(b),b=b in d?[b]:b.split(" ")),e=b.length;while(e--)delete d[b[e]];if(c?!P(d):!m.isEmptyObject(d))return}(c||(delete g[h].data,P(g[h])))&&(f?m.cleanData([a],!0):k.deleteExpando||g!=g.window?delete g[h]:g[h]=null)}}}m.extend({cache:{},noData:{"applet ":!0,"embed ":!0,"object ":"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"},hasData:function(a){return a=a.nodeType?m.cache[a[m.expando]]:a[m.expando],!!a&&!P(a)},data:function(a,b,c){return Q(a,b,c)},removeData:function(a,b){return R(a,b)},_data:function(a,b,c){return Q(a,b,c,!0)},_removeData:function(a,b){return R(a,b,!0)}}),m.fn.extend({data:function(a,b){var c,d,e,f=this[0],g=f&&f.attributes;if(void 0===a){if(this.length&&(e=m.data(f),1===f.nodeType&&!m._data(f,"parsedAttrs"))){c=g.length;while(c--)g[c]&&(d=g[c].name,0===d.indexOf("data-")&&(d=m.camelCase(d.slice(5)),O(f,d,e[d])));m._data(f,"parsedAttrs",!0)}return e}return"object"==typeof a?this.each(function(){m.data(this,a)}):arguments.length>1?this.each(function(){m.data(this,a,b)}):f?O(f,a,m.data(f,a)):void 0},removeData:function(a){return this.each(function(){m.removeData(this,a)})}}),m.extend({queue:function(a,b,c){var d;return a?(b=(b||"fx")+"queue",d=m._data(a,b),c&&(!d||m.isArray(c)?d=m._data(a,b,m.makeArray(c)):d.push(c)),d||[]):void 0},dequeue:function(a,b){b=b||"fx";var c=m.queue(a,b),d=c.length,e=c.shift(),f=m._queueHooks(a,b),g=function(){m.dequeue(a,b)};"inprogress"===e&&(e=c.shift(),d--),e&&("fx"===b&&c.unshift("inprogress"),delete f.stop,e.call(a,g,f)),!d&&f&&f.empty.fire()},_queueHooks:function(a,b){var c=b+"queueHooks";return m._data(a,c)||m._data(a,c,{empty:m.Callbacks("once memory").add(function(){m._removeData(a,b+"queue"),m._removeData(a,c)})})}}),m.fn.extend({queue:function(a,b){var c=2;return"string"!=typeof a&&(b=a,a="fx",c--),arguments.length<c?m.queue(this[0],a):void 0===b?this:this.each(function(){var c=m.queue(this,a,b);m._queueHooks(this,a),"fx"===a&&"inprogress"!==c[0]&&m.dequeue(this,a)})},dequeue:function(a){return this.each(function(){m.dequeue(this,a)})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,b){var c,d=1,e=m.Deferred(),f=this,g=this.length,h=function(){--d||e.resolveWith(f,[f])};"string"!=typeof a&&(b=a,a=void 0),a=a||"fx";while(g--)c=m._data(f[g],a+"queueHooks"),c&&c.empty&&(d++,c.empty.add(h));return h(),e.promise(b)}});var S=/[+-]?(?:\d*\.|)\d+(?:[eE][+-]?\d+|)/.source,T=["Top","Right","Bottom","Left"],U=function(a,b){return a=b||a,"none"===m.css(a,"display")||!m.contains(a.ownerDocument,a)},V=m.access=function(a,b,c,d,e,f,g){var h=0,i=a.length,j=null==c;if("object"===m.type(c)){e=!0;for(h in c)m.access(a,b,h,c[h],!0,f,g)}else if(void 0!==d&&(e=!0,m.isFunction(d)||(g=!0),j&&(g?(b.call(a,d),b=null):(j=b,b=function(a,b,c){return j.call(m(a),c)})),b))for(;i>h;h++)b(a[h],c,g?d:d.call(a[h],h,b(a[h],c)));return e?a:j?b.call(a):i?b(a[0],c):f},W=/^(?:checkbox|radio)$/i;!function(){var a=y.createElement("input"),b=y.createElement("div"),c=y.createDocumentFragment();if(b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",k.leadingWhitespace=3===b.firstChild.nodeType,k.tbody=!b.getElementsByTagName("tbody").length,k.htmlSerialize=!!b.getElementsByTagName("link").length,k.html5Clone="<:nav></:nav>"!==y.createElement("nav").cloneNode(!0).outerHTML,a.type="checkbox",a.checked=!0,c.appendChild(a),k.appendChecked=a.checked,b.innerHTML="<textarea>x</textarea>",k.noCloneChecked=!!b.cloneNode(!0).lastChild.defaultValue,c.appendChild(b),b.innerHTML="<input type='radio' checked='checked' name='t'/>",k.checkClone=b.cloneNode(!0).cloneNode(!0).lastChild.checked,k.noCloneEvent=!0,b.attachEvent&&(b.attachEvent("onclick",function(){k.noCloneEvent=!1}),b.cloneNode(!0).click()),null==k.deleteExpando){k.deleteExpando=!0;try{delete b.test}catch(d){k.deleteExpando=!1}}}(),function(){var b,c,d=y.createElement("div");for(b in{submit:!0,change:!0,focusin:!0})c="on"+b,(k[b+"Bubbles"]=c in a)||(d.setAttribute(c,"t"),k[b+"Bubbles"]=d.attributes[c].expando===!1);d=null}();var X=/^(?:input|select|textarea)$/i,Y=/^key/,Z=/^(?:mouse|pointer|contextmenu)|click/,$=/^(?:focusinfocus|focusoutblur)$/,_=/^([^.]*)(?:\.(.+)|)$/;function ab(){return!0}function bb(){return!1}function cb(){try{return y.activeElement}catch(a){}}m.event={global:{},add:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m._data(a);if(r){c.handler&&(i=c,c=i.handler,e=i.selector),c.guid||(c.guid=m.guid++),(g=r.events)||(g=r.events={}),(k=r.handle)||(k=r.handle=function(a){return typeof m===K||a&&m.event.triggered===a.type?void 0:m.event.dispatch.apply(k.elem,arguments)},k.elem=a),b=(b||"").match(E)||[""],h=b.length;while(h--)f=_.exec(b[h])||[],o=q=f[1],p=(f[2]||"").split(".").sort(),o&&(j=m.event.special[o]||{},o=(e?j.delegateType:j.bindType)||o,j=m.event.special[o]||{},l=m.extend({type:o,origType:q,data:d,handler:c,guid:c.guid,selector:e,needsContext:e&&m.expr.match.needsContext.test(e),namespace:p.join(".")},i),(n=g[o])||(n=g[o]=[],n.delegateCount=0,j.setup&&j.setup.call(a,d,p,k)!==!1||(a.addEventListener?a.addEventListener(o,k,!1):a.attachEvent&&a.attachEvent("on"+o,k))),j.add&&(j.add.call(a,l),l.handler.guid||(l.handler.guid=c.guid)),e?n.splice(n.delegateCount++,0,l):n.push(l),m.event.global[o]=!0);a=null}},remove:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m.hasData(a)&&m._data(a);if(r&&(k=r.events)){b=(b||"").match(E)||[""],j=b.length;while(j--)if(h=_.exec(b[j])||[],o=q=h[1],p=(h[2]||"").split(".").sort(),o){l=m.event.special[o]||{},o=(d?l.delegateType:l.bindType)||o,n=k[o]||[],h=h[2]&&new RegExp("(^|\\.)"+p.join("\\.(?:.*\\.|)")+"(\\.|$)"),i=f=n.length;while(f--)g=n[f],!e&&q!==g.origType||c&&c.guid!==g.guid||h&&!h.test(g.namespace)||d&&d!==g.selector&&("**"!==d||!g.selector)||(n.splice(f,1),g.selector&&n.delegateCount--,l.remove&&l.remove.call(a,g));i&&!n.length&&(l.teardown&&l.teardown.call(a,p,r.handle)!==!1||m.removeEvent(a,o,r.handle),delete k[o])}else for(o in k)m.event.remove(a,o+b[j],c,d,!0);m.isEmptyObject(k)&&(delete r.handle,m._removeData(a,"events"))}},trigger:function(b,c,d,e){var f,g,h,i,k,l,n,o=[d||y],p=j.call(b,"type")?b.type:b,q=j.call(b,"namespace")?b.namespace.split("."):[];if(h=l=d=d||y,3!==d.nodeType&&8!==d.nodeType&&!$.test(p+m.event.triggered)&&(p.indexOf(".")>=0&&(q=p.split("."),p=q.shift(),q.sort()),g=p.indexOf(":")<0&&"on"+p,b=b[m.expando]?b:new m.Event(p,"object"==typeof b&&b),b.isTrigger=e?2:3,b.namespace=q.join("."),b.namespace_re=b.namespace?new RegExp("(^|\\.)"+q.join("\\.(?:.*\\.|)")+"(\\.|$)"):null,b.result=void 0,b.target||(b.target=d),c=null==c?[b]:m.makeArray(c,[b]),k=m.event.special[p]||{},e||!k.trigger||k.trigger.apply(d,c)!==!1)){if(!e&&!k.noBubble&&!m.isWindow(d)){for(i=k.delegateType||p,$.test(i+p)||(h=h.parentNode);h;h=h.parentNode)o.push(h),l=h;l===(d.ownerDocument||y)&&o.push(l.defaultView||l.parentWindow||a)}n=0;while((h=o[n++])&&!b.isPropagationStopped())b.type=n>1?i:k.bindType||p,f=(m._data(h,"events")||{})[b.type]&&m._data(h,"handle"),f&&f.apply(h,c),f=g&&h[g],f&&f.apply&&m.acceptData(h)&&(b.result=f.apply(h,c),b.result===!1&&b.preventDefault());if(b.type=p,!e&&!b.isDefaultPrevented()&&(!k._default||k._default.apply(o.pop(),c)===!1)&&m.acceptData(d)&&g&&d[p]&&!m.isWindow(d)){l=d[g],l&&(d[g]=null),m.event.triggered=p;try{d[p]()}catch(r){}m.event.triggered=void 0,l&&(d[g]=l)}return b.result}},dispatch:function(a){a=m.event.fix(a);var b,c,e,f,g,h=[],i=d.call(arguments),j=(m._data(this,"events")||{})[a.type]||[],k=m.event.special[a.type]||{};if(i[0]=a,a.delegateTarget=this,!k.preDispatch||k.preDispatch.call(this,a)!==!1){h=m.event.handlers.call(this,a,j),b=0;while((f=h[b++])&&!a.isPropagationStopped()){a.currentTarget=f.elem,g=0;while((e=f.handlers[g++])&&!a.isImmediatePropagationStopped())(!a.namespace_re||a.namespace_re.test(e.namespace))&&(a.handleObj=e,a.data=e.data,c=((m.event.special[e.origType]||{}).handle||e.handler).apply(f.elem,i),void 0!==c&&(a.result=c)===!1&&(a.preventDefault(),a.stopPropagation()))}return k.postDispatch&&k.postDispatch.call(this,a),a.result}},handlers:function(a,b){var c,d,e,f,g=[],h=b.delegateCount,i=a.target;if(h&&i.nodeType&&(!a.button||"click"!==a.type))for(;i!=this;i=i.parentNode||this)if(1===i.nodeType&&(i.disabled!==!0||"click"!==a.type)){for(e=[],f=0;h>f;f++)d=b[f],c=d.selector+" ",void 0===e[c]&&(e[c]=d.needsContext?m(c,this).index(i)>=0:m.find(c,this,null,[i]).length),e[c]&&e.push(d);e.length&&g.push({elem:i,handlers:e})}return h<b.length&&g.push({elem:this,handlers:b.slice(h)}),g},fix:function(a){if(a[m.expando])return a;var b,c,d,e=a.type,f=a,g=this.fixHooks[e];g||(this.fixHooks[e]=g=Z.test(e)?this.mouseHooks:Y.test(e)?this.keyHooks:{}),d=g.props?this.props.concat(g.props):this.props,a=new m.Event(f),b=d.length;while(b--)c=d[b],a[c]=f[c];return a.target||(a.target=f.srcElement||y),3===a.target.nodeType&&(a.target=a.target.parentNode),a.metaKey=!!a.metaKey,g.filter?g.filter(a,f):a},props:"altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){return null==a.which&&(a.which=null!=b.charCode?b.charCode:b.keyCode),a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,b){var c,d,e,f=b.button,g=b.fromElement;return null==a.pageX&&null!=b.clientX&&(d=a.target.ownerDocument||y,e=d.documentElement,c=d.body,a.pageX=b.clientX+(e&&e.scrollLeft||c&&c.scrollLeft||0)-(e&&e.clientLeft||c&&c.clientLeft||0),a.pageY=b.clientY+(e&&e.scrollTop||c&&c.scrollTop||0)-(e&&e.clientTop||c&&c.clientTop||0)),!a.relatedTarget&&g&&(a.relatedTarget=g===a.target?b.toElement:g),a.which||void 0===f||(a.which=1&f?1:2&f?3:4&f?2:0),a}},special:{load:{noBubble:!0},focus:{trigger:function(){if(this!==cb()&&this.focus)try{return this.focus(),!1}catch(a){}},delegateType:"focusin"},blur:{trigger:function(){return this===cb()&&this.blur?(this.blur(),!1):void 0},delegateType:"focusout"},click:{trigger:function(){return m.nodeName(this,"input")&&"checkbox"===this.type&&this.click?(this.click(),!1):void 0},_default:function(a){return m.nodeName(a.target,"a")}},beforeunload:{postDispatch:function(a){void 0!==a.result&&a.originalEvent&&(a.originalEvent.returnValue=a.result)}}},simulate:function(a,b,c,d){var e=m.extend(new m.Event,c,{type:a,isSimulated:!0,originalEvent:{}});d?m.event.trigger(e,null,b):m.event.dispatch.call(b,e),e.isDefaultPrevented()&&c.preventDefault()}},m.removeEvent=y.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c,!1)}:function(a,b,c){var d="on"+b;a.detachEvent&&(typeof a[d]===K&&(a[d]=null),a.detachEvent(d,c))},m.Event=function(a,b){return this instanceof m.Event?(a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||void 0===a.defaultPrevented&&a.returnValue===!1?ab:bb):this.type=a,b&&m.extend(this,b),this.timeStamp=a&&a.timeStamp||m.now(),void(this[m.expando]=!0)):new m.Event(a,b)},m.Event.prototype={isDefaultPrevented:bb,isPropagationStopped:bb,isImmediatePropagationStopped:bb,preventDefault:function(){var a=this.originalEvent;this.isDefaultPrevented=ab,a&&(a.preventDefault?a.preventDefault():a.returnValue=!1)},stopPropagation:function(){var a=this.originalEvent;this.isPropagationStopped=ab,a&&(a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0)},stopImmediatePropagation:function(){var a=this.originalEvent;this.isImmediatePropagationStopped=ab,a&&a.stopImmediatePropagation&&a.stopImmediatePropagation(),this.stopPropagation()}},m.each({mouseenter:"mouseover",mouseleave:"mouseout",pointerenter:"pointerover",pointerleave:"pointerout"},function(a,b){m.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c,d=this,e=a.relatedTarget,f=a.handleObj;return(!e||e!==d&&!m.contains(d,e))&&(a.type=f.origType,c=f.handler.apply(this,arguments),a.type=b),c}}}),k.submitBubbles||(m.event.special.submit={setup:function(){return m.nodeName(this,"form")?!1:void m.event.add(this,"click._submit keypress._submit",function(a){var b=a.target,c=m.nodeName(b,"input")||m.nodeName(b,"button")?b.form:void 0;c&&!m._data(c,"submitBubbles")&&(m.event.add(c,"submit._submit",function(a){a._submit_bubble=!0}),m._data(c,"submitBubbles",!0))})},postDispatch:function(a){a._submit_bubble&&(delete a._submit_bubble,this.parentNode&&!a.isTrigger&&m.event.simulate("submit",this.parentNode,a,!0))},teardown:function(){return m.nodeName(this,"form")?!1:void m.event.remove(this,"._submit")}}),k.changeBubbles||(m.event.special.change={setup:function(){return X.test(this.nodeName)?(("checkbox"===this.type||"radio"===this.type)&&(m.event.add(this,"propertychange._change",function(a){"checked"===a.originalEvent.propertyName&&(this._just_changed=!0)}),m.event.add(this,"click._change",function(a){this._just_changed&&!a.isTrigger&&(this._just_changed=!1),m.event.simulate("change",this,a,!0)})),!1):void m.event.add(this,"beforeactivate._change",function(a){var b=a.target;X.test(b.nodeName)&&!m._data(b,"changeBubbles")&&(m.event.add(b,"change._change",function(a){!this.parentNode||a.isSimulated||a.isTrigger||m.event.simulate("change",this.parentNode,a,!0)}),m._data(b,"changeBubbles",!0))})},handle:function(a){var b=a.target;return this!==b||a.isSimulated||a.isTrigger||"radio"!==b.type&&"checkbox"!==b.type?a.handleObj.handler.apply(this,arguments):void 0},teardown:function(){return m.event.remove(this,"._change"),!X.test(this.nodeName)}}),k.focusinBubbles||m.each({focus:"focusin",blur:"focusout"},function(a,b){var c=function(a){m.event.simulate(b,a.target,m.event.fix(a),!0)};m.event.special[b]={setup:function(){var d=this.ownerDocument||this,e=m._data(d,b);e||d.addEventListener(a,c,!0),m._data(d,b,(e||0)+1)},teardown:function(){var d=this.ownerDocument||this,e=m._data(d,b)-1;e?m._data(d,b,e):(d.removeEventListener(a,c,!0),m._removeData(d,b))}}}),m.fn.extend({on:function(a,b,c,d,e){var f,g;if("object"==typeof a){"string"!=typeof b&&(c=c||b,b=void 0);for(f in a)this.on(f,b,c,a[f],e);return this}if(null==c&&null==d?(d=b,c=b=void 0):null==d&&("string"==typeof b?(d=c,c=void 0):(d=c,c=b,b=void 0)),d===!1)d=bb;else if(!d)return this;return 1===e&&(g=d,d=function(a){return m().off(a),g.apply(this,arguments)},d.guid=g.guid||(g.guid=m.guid++)),this.each(function(){m.event.add(this,a,d,c,b)})},one:function(a,b,c,d){return this.on(a,b,c,d,1)},off:function(a,b,c){var d,e;if(a&&a.preventDefault&&a.handleObj)return d=a.handleObj,m(a.delegateTarget).off(d.namespace?d.origType+"."+d.namespace:d.origType,d.selector,d.handler),this;if("object"==typeof a){for(e in a)this.off(e,b,a[e]);return this}return(b===!1||"function"==typeof b)&&(c=b,b=void 0),c===!1&&(c=bb),this.each(function(){m.event.remove(this,a,c,b)})},trigger:function(a,b){return this.each(function(){m.event.trigger(a,b,this)})},triggerHandler:function(a,b){var c=this[0];return c?m.event.trigger(a,b,c,!0):void 0}});function db(a){var b=eb.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}var eb="abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",fb=/ jQuery\d+="(?:null|\d+)"/g,gb=new RegExp("<(?:"+eb+")[\\s/>]","i"),hb=/^\s+/,ib=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/gi,jb=/<([\w:]+)/,kb=/<tbody/i,lb=/<|&#?\w+;/,mb=/<(?:script|style|link)/i,nb=/checked\s*(?:[^=]|=\s*.checked.)/i,ob=/^$|\/(?:java|ecma)script/i,pb=/^true\/(.*)/,qb=/^\s*<!(?:\[CDATA\[|--)|(?:\]\]|--)>\s*$/g,rb={option:[1,"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],area:[1,"<map>","</map>"],param:[1,"<object>","</object>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],_default:k.htmlSerialize?[0,"",""]:[1,"X<div>","</div>"]},sb=db(y),tb=sb.appendChild(y.createElement("div"));rb.optgroup=rb.option,rb.tbody=rb.tfoot=rb.colgroup=rb.caption=rb.thead,rb.th=rb.td;function ub(a,b){var c,d,e=0,f=typeof a.getElementsByTagName!==K?a.getElementsByTagName(b||"*"):typeof a.querySelectorAll!==K?a.querySelectorAll(b||"*"):void 0;if(!f)for(f=[],c=a.childNodes||a;null!=(d=c[e]);e++)!b||m.nodeName(d,b)?f.push(d):m.merge(f,ub(d,b));return void 0===b||b&&m.nodeName(a,b)?m.merge([a],f):f}function vb(a){W.test(a.type)&&(a.defaultChecked=a.checked)}function wb(a,b){return m.nodeName(a,"table")&&m.nodeName(11!==b.nodeType?b:b.firstChild,"tr")?a.getElementsByTagName("tbody")[0]||a.appendChild(a.ownerDocument.createElement("tbody")):a}function xb(a){return a.type=(null!==m.find.attr(a,"type"))+"/"+a.type,a}function yb(a){var b=pb.exec(a.type);return b?a.type=b[1]:a.removeAttribute("type"),a}function zb(a,b){for(var c,d=0;null!=(c=a[d]);d++)m._data(c,"globalEval",!b||m._data(b[d],"globalEval"))}function Ab(a,b){if(1===b.nodeType&&m.hasData(a)){var c,d,e,f=m._data(a),g=m._data(b,f),h=f.events;if(h){delete g.handle,g.events={};for(c in h)for(d=0,e=h[c].length;e>d;d++)m.event.add(b,c,h[c][d])}g.data&&(g.data=m.extend({},g.data))}}function Bb(a,b){var c,d,e;if(1===b.nodeType){if(c=b.nodeName.toLowerCase(),!k.noCloneEvent&&b[m.expando]){e=m._data(b);for(d in e.events)m.removeEvent(b,d,e.handle);b.removeAttribute(m.expando)}"script"===c&&b.text!==a.text?(xb(b).text=a.text,yb(b)):"object"===c?(b.parentNode&&(b.outerHTML=a.outerHTML),k.html5Clone&&a.innerHTML&&!m.trim(b.innerHTML)&&(b.innerHTML=a.innerHTML)):"input"===c&&W.test(a.type)?(b.defaultChecked=b.checked=a.checked,b.value!==a.value&&(b.value=a.value)):"option"===c?b.defaultSelected=b.selected=a.defaultSelected:("input"===c||"textarea"===c)&&(b.defaultValue=a.defaultValue)}}m.extend({clone:function(a,b,c){var d,e,f,g,h,i=m.contains(a.ownerDocument,a);if(k.html5Clone||m.isXMLDoc(a)||!gb.test("<"+a.nodeName+">")?f=a.cloneNode(!0):(tb.innerHTML=a.outerHTML,tb.removeChild(f=tb.firstChild)),!(k.noCloneEvent&&k.noCloneChecked||1!==a.nodeType&&11!==a.nodeType||m.isXMLDoc(a)))for(d=ub(f),h=ub(a),g=0;null!=(e=h[g]);++g)d[g]&&Bb(e,d[g]);if(b)if(c)for(h=h||ub(a),d=d||ub(f),g=0;null!=(e=h[g]);g++)Ab(e,d[g]);else Ab(a,f);return d=ub(f,"script"),d.length>0&&zb(d,!i&&ub(a,"script")),d=h=e=null,f},buildFragment:function(a,b,c,d){for(var e,f,g,h,i,j,l,n=a.length,o=db(b),p=[],q=0;n>q;q++)if(f=a[q],f||0===f)if("object"===m.type(f))m.merge(p,f.nodeType?[f]:f);else if(lb.test(f)){h=h||o.appendChild(b.createElement("div")),i=(jb.exec(f)||["",""])[1].toLowerCase(),l=rb[i]||rb._default,h.innerHTML=l[1]+f.replace(ib,"<$1></$2>")+l[2],e=l[0];while(e--)h=h.lastChild;if(!k.leadingWhitespace&&hb.test(f)&&p.push(b.createTextNode(hb.exec(f)[0])),!k.tbody){f="table"!==i||kb.test(f)?"<table>"!==l[1]||kb.test(f)?0:h:h.firstChild,e=f&&f.childNodes.length;while(e--)m.nodeName(j=f.childNodes[e],"tbody")&&!j.childNodes.length&&f.removeChild(j)}m.merge(p,h.childNodes),h.textContent="";while(h.firstChild)h.removeChild(h.firstChild);h=o.lastChild}else p.push(b.createTextNode(f));h&&o.removeChild(h),k.appendChecked||m.grep(ub(p,"input"),vb),q=0;while(f=p[q++])if((!d||-1===m.inArray(f,d))&&(g=m.contains(f.ownerDocument,f),h=ub(o.appendChild(f),"script"),g&&zb(h),c)){e=0;while(f=h[e++])ob.test(f.type||"")&&c.push(f)}return h=null,o},cleanData:function(a,b){for(var d,e,f,g,h=0,i=m.expando,j=m.cache,l=k.deleteExpando,n=m.event.special;null!=(d=a[h]);h++)if((b||m.acceptData(d))&&(f=d[i],g=f&&j[f])){if(g.events)for(e in g.events)n[e]?m.event.remove(d,e):m.removeEvent(d,e,g.handle);j[f]&&(delete j[f],l?delete d[i]:typeof d.removeAttribute!==K?d.removeAttribute(i):d[i]=null,c.push(f))}}}),m.fn.extend({text:function(a){return V(this,function(a){return void 0===a?m.text(this):this.empty().append((this[0]&&this[0].ownerDocument||y).createTextNode(a))},null,a,arguments.length)},append:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.appendChild(a)}})},prepend:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.insertBefore(a,b.firstChild)}})},before:function(){return this.domManip(arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this)})},after:function(){return this.domManip(arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this.nextSibling)})},remove:function(a,b){for(var c,d=a?m.filter(a,this):this,e=0;null!=(c=d[e]);e++)b||1!==c.nodeType||m.cleanData(ub(c)),c.parentNode&&(b&&m.contains(c.ownerDocument,c)&&zb(ub(c,"script")),c.parentNode.removeChild(c));return this},empty:function(){for(var a,b=0;null!=(a=this[b]);b++){1===a.nodeType&&m.cleanData(ub(a,!1));while(a.firstChild)a.removeChild(a.firstChild);a.options&&m.nodeName(a,"select")&&(a.options.length=0)}return this},clone:function(a,b){return a=null==a?!1:a,b=null==b?a:b,this.map(function(){return m.clone(this,a,b)})},html:function(a){return V(this,function(a){var b=this[0]||{},c=0,d=this.length;if(void 0===a)return 1===b.nodeType?b.innerHTML.replace(fb,""):void 0;if(!("string"!=typeof a||mb.test(a)||!k.htmlSerialize&&gb.test(a)||!k.leadingWhitespace&&hb.test(a)||rb[(jb.exec(a)||["",""])[1].toLowerCase()])){a=a.replace(ib,"<$1></$2>");try{for(;d>c;c++)b=this[c]||{},1===b.nodeType&&(m.cleanData(ub(b,!1)),b.innerHTML=a);b=0}catch(e){}}b&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(){var a=arguments[0];return this.domManip(arguments,function(b){a=this.parentNode,m.cleanData(ub(this)),a&&a.replaceChild(b,this)}),a&&(a.length||a.nodeType)?this:this.remove()},detach:function(a){return this.remove(a,!0)},domManip:function(a,b){a=e.apply([],a);var c,d,f,g,h,i,j=0,l=this.length,n=this,o=l-1,p=a[0],q=m.isFunction(p);if(q||l>1&&"string"==typeof p&&!k.checkClone&&nb.test(p))return this.each(function(c){var d=n.eq(c);q&&(a[0]=p.call(this,c,d.html())),d.domManip(a,b)});if(l&&(i=m.buildFragment(a,this[0].ownerDocument,!1,this),c=i.firstChild,1===i.childNodes.length&&(i=c),c)){for(g=m.map(ub(i,"script"),xb),f=g.length;l>j;j++)d=i,j!==o&&(d=m.clone(d,!0,!0),f&&m.merge(g,ub(d,"script"))),b.call(this[j],d,j);if(f)for(h=g[g.length-1].ownerDocument,m.map(g,yb),j=0;f>j;j++)d=g[j],ob.test(d.type||"")&&!m._data(d,"globalEval")&&m.contains(h,d)&&(d.src?m._evalUrl&&m._evalUrl(d.src):m.globalEval((d.text||d.textContent||d.innerHTML||"").replace(qb,"")));i=c=null}return this}}),m.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){m.fn[a]=function(a){for(var c,d=0,e=[],g=m(a),h=g.length-1;h>=d;d++)c=d===h?this:this.clone(!0),m(g[d])[b](c),f.apply(e,c.get());return this.pushStack(e)}});var Cb,Db={};function Eb(b,c){var d,e=m(c.createElement(b)).appendTo(c.body),f=a.getDefaultComputedStyle&&(d=a.getDefaultComputedStyle(e[0]))?d.display:m.css(e[0],"display");return e.detach(),f}function Fb(a){var b=y,c=Db[a];return c||(c=Eb(a,b),"none"!==c&&c||(Cb=(Cb||m("<iframe frameborder='0' width='0' height='0'/>")).appendTo(b.documentElement),b=(Cb[0].contentWindow||Cb[0].contentDocument).document,b.write(),b.close(),c=Eb(a,b),Cb.detach()),Db[a]=c),c}!function(){var a;k.shrinkWrapBlocks=function(){if(null!=a)return a;a=!1;var b,c,d;return c=y.getElementsByTagName("body")[0],c&&c.style?(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:1px;width:1px;zoom:1",b.appendChild(y.createElement("div")).style.width="5px",a=3!==b.offsetWidth),c.removeChild(d),a):void 0}}();var Gb=/^margin/,Hb=new RegExp("^("+S+")(?!px)[a-z%]+$","i"),Ib,Jb,Kb=/^(top|right|bottom|left)$/;a.getComputedStyle?(Ib=function(a){return a.ownerDocument.defaultView.getComputedStyle(a,null)},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c.getPropertyValue(b)||c[b]:void 0,c&&(""!==g||m.contains(a.ownerDocument,a)||(g=m.style(a,b)),Hb.test(g)&&Gb.test(b)&&(d=h.width,e=h.minWidth,f=h.maxWidth,h.minWidth=h.maxWidth=h.width=g,g=c.width,h.width=d,h.minWidth=e,h.maxWidth=f)),void 0===g?g:g+""}):y.documentElement.currentStyle&&(Ib=function(a){return a.currentStyle},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c[b]:void 0,null==g&&h&&h[b]&&(g=h[b]),Hb.test(g)&&!Kb.test(b)&&(d=h.left,e=a.runtimeStyle,f=e&&e.left,f&&(e.left=a.currentStyle.left),h.left="fontSize"===b?"1em":g,g=h.pixelLeft+"px",h.left=d,f&&(e.left=f)),void 0===g?g:g+""||"auto"});function Lb(a,b){return{get:function(){var c=a();if(null!=c)return c?void delete this.get:(this.get=b).apply(this,arguments)}}}!function(){var b,c,d,e,f,g,h;if(b=y.createElement("div"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=d&&d.style){c.cssText="float:left;opacity:.5",k.opacity="0.5"===c.opacity,k.cssFloat=!!c.cssFloat,b.style.backgroundClip="content-box",b.cloneNode(!0).style.backgroundClip="",k.clearCloneStyle="content-box"===b.style.backgroundClip,k.boxSizing=""===c.boxSizing||""===c.MozBoxSizing||""===c.WebkitBoxSizing,m.extend(k,{reliableHiddenOffsets:function(){return null==g&&i(),g},boxSizingReliable:function(){return null==f&&i(),f},pixelPosition:function(){return null==e&&i(),e},reliableMarginRight:function(){return null==h&&i(),h}});function i(){var b,c,d,i;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),b.style.cssText="-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;display:block;margin-top:1%;top:1%;border:1px;padding:1px;width:4px;position:absolute",e=f=!1,h=!0,a.getComputedStyle&&(e="1%"!==(a.getComputedStyle(b,null)||{}).top,f="4px"===(a.getComputedStyle(b,null)||{width:"4px"}).width,i=b.appendChild(y.createElement("div")),i.style.cssText=b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:0",i.style.marginRight=i.style.width="0",b.style.width="1px",h=!parseFloat((a.getComputedStyle(i,null)||{}).marginRight)),b.innerHTML="<table><tr><td></td><td>t</td></tr></table>",i=b.getElementsByTagName("td"),i[0].style.cssText="margin:0;border:0;padding:0;display:none",g=0===i[0].offsetHeight,g&&(i[0].style.display="",i[1].style.display="none",g=0===i[0].offsetHeight),c.removeChild(d))}}}(),m.swap=function(a,b,c,d){var e,f,g={};for(f in b)g[f]=a.style[f],a.style[f]=b[f];e=c.apply(a,d||[]);for(f in b)a.style[f]=g[f];return e};var Mb=/alpha\([^)]*\)/i,Nb=/opacity\s*=\s*([^)]*)/,Ob=/^(none|table(?!-c[ea]).+)/,Pb=new RegExp("^("+S+")(.*)$","i"),Qb=new RegExp("^([+-])=("+S+")","i"),Rb={position:"absolute",visibility:"hidden",display:"block"},Sb={letterSpacing:"0",fontWeight:"400"},Tb=["Webkit","O","Moz","ms"];function Ub(a,b){if(b in a)return b;var c=b.charAt(0).toUpperCase()+b.slice(1),d=b,e=Tb.length;while(e--)if(b=Tb[e]+c,b in a)return b;return d}function Vb(a,b){for(var c,d,e,f=[],g=0,h=a.length;h>g;g++)d=a[g],d.style&&(f[g]=m._data(d,"olddisplay"),c=d.style.display,b?(f[g]||"none"!==c||(d.style.display=""),""===d.style.display&&U(d)&&(f[g]=m._data(d,"olddisplay",Fb(d.nodeName)))):(e=U(d),(c&&"none"!==c||!e)&&m._data(d,"olddisplay",e?c:m.css(d,"display"))));for(g=0;h>g;g++)d=a[g],d.style&&(b&&"none"!==d.style.display&&""!==d.style.display||(d.style.display=b?f[g]||"":"none"));return a}function Wb(a,b,c){var d=Pb.exec(b);return d?Math.max(0,d[1]-(c||0))+(d[2]||"px"):b}function Xb(a,b,c,d,e){for(var f=c===(d?"border":"content")?4:"width"===b?1:0,g=0;4>f;f+=2)"margin"===c&&(g+=m.css(a,c+T[f],!0,e)),d?("content"===c&&(g-=m.css(a,"padding"+T[f],!0,e)),"margin"!==c&&(g-=m.css(a,"border"+T[f]+"Width",!0,e))):(g+=m.css(a,"padding"+T[f],!0,e),"padding"!==c&&(g+=m.css(a,"border"+T[f]+"Width",!0,e)));return g}function Yb(a,b,c){var d=!0,e="width"===b?a.offsetWidth:a.offsetHeight,f=Ib(a),g=k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,f);if(0>=e||null==e){if(e=Jb(a,b,f),(0>e||null==e)&&(e=a.style[b]),Hb.test(e))return e;d=g&&(k.boxSizingReliable()||e===a.style[b]),e=parseFloat(e)||0}return e+Xb(a,b,c||(g?"border":"content"),d,f)+"px"}m.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=Jb(a,"opacity");return""===c?"1":c}}}},cssNumber:{columnCount:!0,fillOpacity:!0,flexGrow:!0,flexShrink:!0,fontWeight:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":k.cssFloat?"cssFloat":"styleFloat"},style:function(a,b,c,d){if(a&&3!==a.nodeType&&8!==a.nodeType&&a.style){var e,f,g,h=m.camelCase(b),i=a.style;if(b=m.cssProps[h]||(m.cssProps[h]=Ub(i,h)),g=m.cssHooks[b]||m.cssHooks[h],void 0===c)return g&&"get"in g&&void 0!==(e=g.get(a,!1,d))?e:i[b];if(f=typeof c,"string"===f&&(e=Qb.exec(c))&&(c=(e[1]+1)*e[2]+parseFloat(m.css(a,b)),f="number"),null!=c&&c===c&&("number"!==f||m.cssNumber[h]||(c+="px"),k.clearCloneStyle||""!==c||0!==b.indexOf("background")||(i[b]="inherit"),!(g&&"set"in g&&void 0===(c=g.set(a,c,d)))))try{i[b]=c}catch(j){}}},css:function(a,b,c,d){var e,f,g,h=m.camelCase(b);return b=m.cssProps[h]||(m.cssProps[h]=Ub(a.style,h)),g=m.cssHooks[b]||m.cssHooks[h],g&&"get"in g&&(f=g.get(a,!0,c)),void 0===f&&(f=Jb(a,b,d)),"normal"===f&&b in Sb&&(f=Sb[b]),""===c||c?(e=parseFloat(f),c===!0||m.isNumeric(e)?e||0:f):f}}),m.each(["height","width"],function(a,b){m.cssHooks[b]={get:function(a,c,d){return c?Ob.test(m.css(a,"display"))&&0===a.offsetWidth?m.swap(a,Rb,function(){return Yb(a,b,d)}):Yb(a,b,d):void 0},set:function(a,c,d){var e=d&&Ib(a);return Wb(a,c,d?Xb(a,b,d,k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,e),e):0)}}}),k.opacity||(m.cssHooks.opacity={get:function(a,b){return Nb.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?.01*parseFloat(RegExp.$1)+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=m.isNumeric(b)?"alpha(opacity="+100*b+")":"",f=d&&d.filter||c.filter||"";c.zoom=1,(b>=1||""===b)&&""===m.trim(f.replace(Mb,""))&&c.removeAttribute&&(c.removeAttribute("filter"),""===b||d&&!d.filter)||(c.filter=Mb.test(f)?f.replace(Mb,e):f+" "+e)}}),m.cssHooks.marginRight=Lb(k.reliableMarginRight,function(a,b){return b?m.swap(a,{display:"inline-block"},Jb,[a,"marginRight"]):void 0}),m.each({margin:"",padding:"",border:"Width"},function(a,b){m.cssHooks[a+b]={expand:function(c){for(var d=0,e={},f="string"==typeof c?c.split(" "):[c];4>d;d++)e[a+T[d]+b]=f[d]||f[d-2]||f[0];return e}},Gb.test(a)||(m.cssHooks[a+b].set=Wb)}),m.fn.extend({css:function(a,b){return V(this,function(a,b,c){var d,e,f={},g=0;if(m.isArray(b)){for(d=Ib(a),e=b.length;e>g;g++)f[b[g]]=m.css(a,b[g],!1,d);return f}return void 0!==c?m.style(a,b,c):m.css(a,b)},a,b,arguments.length>1)},show:function(){return Vb(this,!0)},hide:function(){return Vb(this)},toggle:function(a){return"boolean"==typeof a?a?this.show():this.hide():this.each(function(){U(this)?m(this).show():m(this).hide()})}});function Zb(a,b,c,d,e){return new Zb.prototype.init(a,b,c,d,e)}m.Tween=Zb,Zb.prototype={constructor:Zb,init:function(a,b,c,d,e,f){this.elem=a,this.prop=c,this.easing=e||"swing",this.options=b,this.start=this.now=this.cur(),this.end=d,this.unit=f||(m.cssNumber[c]?"":"px")
},cur:function(){var a=Zb.propHooks[this.prop];return a&&a.get?a.get(this):Zb.propHooks._default.get(this)},run:function(a){var b,c=Zb.propHooks[this.prop];return this.pos=b=this.options.duration?m.easing[this.easing](a,this.options.duration*a,0,1,this.options.duration):a,this.now=(this.end-this.start)*b+this.start,this.options.step&&this.options.step.call(this.elem,this.now,this),c&&c.set?c.set(this):Zb.propHooks._default.set(this),this}},Zb.prototype.init.prototype=Zb.prototype,Zb.propHooks={_default:{get:function(a){var b;return null==a.elem[a.prop]||a.elem.style&&null!=a.elem.style[a.prop]?(b=m.css(a.elem,a.prop,""),b&&"auto"!==b?b:0):a.elem[a.prop]},set:function(a){m.fx.step[a.prop]?m.fx.step[a.prop](a):a.elem.style&&(null!=a.elem.style[m.cssProps[a.prop]]||m.cssHooks[a.prop])?m.style(a.elem,a.prop,a.now+a.unit):a.elem[a.prop]=a.now}}},Zb.propHooks.scrollTop=Zb.propHooks.scrollLeft={set:function(a){a.elem.nodeType&&a.elem.parentNode&&(a.elem[a.prop]=a.now)}},m.easing={linear:function(a){return a},swing:function(a){return.5-Math.cos(a*Math.PI)/2}},m.fx=Zb.prototype.init,m.fx.step={};var $b,_b,ac=/^(?:toggle|show|hide)$/,bc=new RegExp("^(?:([+-])=|)("+S+")([a-z%]*)$","i"),cc=/queueHooks$/,dc=[ic],ec={"*":[function(a,b){var c=this.createTween(a,b),d=c.cur(),e=bc.exec(b),f=e&&e[3]||(m.cssNumber[a]?"":"px"),g=(m.cssNumber[a]||"px"!==f&&+d)&&bc.exec(m.css(c.elem,a)),h=1,i=20;if(g&&g[3]!==f){f=f||g[3],e=e||[],g=+d||1;do h=h||".5",g/=h,m.style(c.elem,a,g+f);while(h!==(h=c.cur()/d)&&1!==h&&--i)}return e&&(g=c.start=+g||+d||0,c.unit=f,c.end=e[1]?g+(e[1]+1)*e[2]:+e[2]),c}]};function fc(){return setTimeout(function(){$b=void 0}),$b=m.now()}function gc(a,b){var c,d={height:a},e=0;for(b=b?1:0;4>e;e+=2-b)c=T[e],d["margin"+c]=d["padding"+c]=a;return b&&(d.opacity=d.width=a),d}function hc(a,b,c){for(var d,e=(ec[b]||[]).concat(ec["*"]),f=0,g=e.length;g>f;f++)if(d=e[f].call(c,b,a))return d}function ic(a,b,c){var d,e,f,g,h,i,j,l,n=this,o={},p=a.style,q=a.nodeType&&U(a),r=m._data(a,"fxshow");c.queue||(h=m._queueHooks(a,"fx"),null==h.unqueued&&(h.unqueued=0,i=h.empty.fire,h.empty.fire=function(){h.unqueued||i()}),h.unqueued++,n.always(function(){n.always(function(){h.unqueued--,m.queue(a,"fx").length||h.empty.fire()})})),1===a.nodeType&&("height"in b||"width"in b)&&(c.overflow=[p.overflow,p.overflowX,p.overflowY],j=m.css(a,"display"),l="none"===j?m._data(a,"olddisplay")||Fb(a.nodeName):j,"inline"===l&&"none"===m.css(a,"float")&&(k.inlineBlockNeedsLayout&&"inline"!==Fb(a.nodeName)?p.zoom=1:p.display="inline-block")),c.overflow&&(p.overflow="hidden",k.shrinkWrapBlocks()||n.always(function(){p.overflow=c.overflow[0],p.overflowX=c.overflow[1],p.overflowY=c.overflow[2]}));for(d in b)if(e=b[d],ac.exec(e)){if(delete b[d],f=f||"toggle"===e,e===(q?"hide":"show")){if("show"!==e||!r||void 0===r[d])continue;q=!0}o[d]=r&&r[d]||m.style(a,d)}else j=void 0;if(m.isEmptyObject(o))"inline"===("none"===j?Fb(a.nodeName):j)&&(p.display=j);else{r?"hidden"in r&&(q=r.hidden):r=m._data(a,"fxshow",{}),f&&(r.hidden=!q),q?m(a).show():n.done(function(){m(a).hide()}),n.done(function(){var b;m._removeData(a,"fxshow");for(b in o)m.style(a,b,o[b])});for(d in o)g=hc(q?r[d]:0,d,n),d in r||(r[d]=g.start,q&&(g.end=g.start,g.start="width"===d||"height"===d?1:0))}}function jc(a,b){var c,d,e,f,g;for(c in a)if(d=m.camelCase(c),e=b[d],f=a[c],m.isArray(f)&&(e=f[1],f=a[c]=f[0]),c!==d&&(a[d]=f,delete a[c]),g=m.cssHooks[d],g&&"expand"in g){f=g.expand(f),delete a[d];for(c in f)c in a||(a[c]=f[c],b[c]=e)}else b[d]=e}function kc(a,b,c){var d,e,f=0,g=dc.length,h=m.Deferred().always(function(){delete i.elem}),i=function(){if(e)return!1;for(var b=$b||fc(),c=Math.max(0,j.startTime+j.duration-b),d=c/j.duration||0,f=1-d,g=0,i=j.tweens.length;i>g;g++)j.tweens[g].run(f);return h.notifyWith(a,[j,f,c]),1>f&&i?c:(h.resolveWith(a,[j]),!1)},j=h.promise({elem:a,props:m.extend({},b),opts:m.extend(!0,{specialEasing:{}},c),originalProperties:b,originalOptions:c,startTime:$b||fc(),duration:c.duration,tweens:[],createTween:function(b,c){var d=m.Tween(a,j.opts,b,c,j.opts.specialEasing[b]||j.opts.easing);return j.tweens.push(d),d},stop:function(b){var c=0,d=b?j.tweens.length:0;if(e)return this;for(e=!0;d>c;c++)j.tweens[c].run(1);return b?h.resolveWith(a,[j,b]):h.rejectWith(a,[j,b]),this}}),k=j.props;for(jc(k,j.opts.specialEasing);g>f;f++)if(d=dc[f].call(j,a,k,j.opts))return d;return m.map(k,hc,j),m.isFunction(j.opts.start)&&j.opts.start.call(a,j),m.fx.timer(m.extend(i,{elem:a,anim:j,queue:j.opts.queue})),j.progress(j.opts.progress).done(j.opts.done,j.opts.complete).fail(j.opts.fail).always(j.opts.always)}m.Animation=m.extend(kc,{tweener:function(a,b){m.isFunction(a)?(b=a,a=["*"]):a=a.split(" ");for(var c,d=0,e=a.length;e>d;d++)c=a[d],ec[c]=ec[c]||[],ec[c].unshift(b)},prefilter:function(a,b){b?dc.unshift(a):dc.push(a)}}),m.speed=function(a,b,c){var d=a&&"object"==typeof a?m.extend({},a):{complete:c||!c&&b||m.isFunction(a)&&a,duration:a,easing:c&&b||b&&!m.isFunction(b)&&b};return d.duration=m.fx.off?0:"number"==typeof d.duration?d.duration:d.duration in m.fx.speeds?m.fx.speeds[d.duration]:m.fx.speeds._default,(null==d.queue||d.queue===!0)&&(d.queue="fx"),d.old=d.complete,d.complete=function(){m.isFunction(d.old)&&d.old.call(this),d.queue&&m.dequeue(this,d.queue)},d},m.fn.extend({fadeTo:function(a,b,c,d){return this.filter(U).css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){var e=m.isEmptyObject(a),f=m.speed(b,c,d),g=function(){var b=kc(this,m.extend({},a),f);(e||m._data(this,"finish"))&&b.stop(!0)};return g.finish=g,e||f.queue===!1?this.each(g):this.queue(f.queue,g)},stop:function(a,b,c){var d=function(a){var b=a.stop;delete a.stop,b(c)};return"string"!=typeof a&&(c=b,b=a,a=void 0),b&&a!==!1&&this.queue(a||"fx",[]),this.each(function(){var b=!0,e=null!=a&&a+"queueHooks",f=m.timers,g=m._data(this);if(e)g[e]&&g[e].stop&&d(g[e]);else for(e in g)g[e]&&g[e].stop&&cc.test(e)&&d(g[e]);for(e=f.length;e--;)f[e].elem!==this||null!=a&&f[e].queue!==a||(f[e].anim.stop(c),b=!1,f.splice(e,1));(b||!c)&&m.dequeue(this,a)})},finish:function(a){return a!==!1&&(a=a||"fx"),this.each(function(){var b,c=m._data(this),d=c[a+"queue"],e=c[a+"queueHooks"],f=m.timers,g=d?d.length:0;for(c.finish=!0,m.queue(this,a,[]),e&&e.stop&&e.stop.call(this,!0),b=f.length;b--;)f[b].elem===this&&f[b].queue===a&&(f[b].anim.stop(!0),f.splice(b,1));for(b=0;g>b;b++)d[b]&&d[b].finish&&d[b].finish.call(this);delete c.finish})}}),m.each(["toggle","show","hide"],function(a,b){var c=m.fn[b];m.fn[b]=function(a,d,e){return null==a||"boolean"==typeof a?c.apply(this,arguments):this.animate(gc(b,!0),a,d,e)}}),m.each({slideDown:gc("show"),slideUp:gc("hide"),slideToggle:gc("toggle"),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){m.fn[a]=function(a,c,d){return this.animate(b,a,c,d)}}),m.timers=[],m.fx.tick=function(){var a,b=m.timers,c=0;for($b=m.now();c<b.length;c++)a=b[c],a()||b[c]!==a||b.splice(c--,1);b.length||m.fx.stop(),$b=void 0},m.fx.timer=function(a){m.timers.push(a),a()?m.fx.start():m.timers.pop()},m.fx.interval=13,m.fx.start=function(){_b||(_b=setInterval(m.fx.tick,m.fx.interval))},m.fx.stop=function(){clearInterval(_b),_b=null},m.fx.speeds={slow:600,fast:200,_default:400},m.fn.delay=function(a,b){return a=m.fx?m.fx.speeds[a]||a:a,b=b||"fx",this.queue(b,function(b,c){var d=setTimeout(b,a);c.stop=function(){clearTimeout(d)}})},function(){var a,b,c,d,e;b=y.createElement("div"),b.setAttribute("className","t"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=y.createElement("select"),e=c.appendChild(y.createElement("option")),a=b.getElementsByTagName("input")[0],d.style.cssText="top:1px",k.getSetAttribute="t"!==b.className,k.style=/top/.test(d.getAttribute("style")),k.hrefNormalized="/a"===d.getAttribute("href"),k.checkOn=!!a.value,k.optSelected=e.selected,k.enctype=!!y.createElement("form").enctype,c.disabled=!0,k.optDisabled=!e.disabled,a=y.createElement("input"),a.setAttribute("value",""),k.input=""===a.getAttribute("value"),a.value="t",a.setAttribute("type","radio"),k.radioValue="t"===a.value}();var lc=/\r/g;m.fn.extend({val:function(a){var b,c,d,e=this[0];{if(arguments.length)return d=m.isFunction(a),this.each(function(c){var e;1===this.nodeType&&(e=d?a.call(this,c,m(this).val()):a,null==e?e="":"number"==typeof e?e+="":m.isArray(e)&&(e=m.map(e,function(a){return null==a?"":a+""})),b=m.valHooks[this.type]||m.valHooks[this.nodeName.toLowerCase()],b&&"set"in b&&void 0!==b.set(this,e,"value")||(this.value=e))});if(e)return b=m.valHooks[e.type]||m.valHooks[e.nodeName.toLowerCase()],b&&"get"in b&&void 0!==(c=b.get(e,"value"))?c:(c=e.value,"string"==typeof c?c.replace(lc,""):null==c?"":c)}}}),m.extend({valHooks:{option:{get:function(a){var b=m.find.attr(a,"value");return null!=b?b:m.trim(m.text(a))}},select:{get:function(a){for(var b,c,d=a.options,e=a.selectedIndex,f="select-one"===a.type||0>e,g=f?null:[],h=f?e+1:d.length,i=0>e?h:f?e:0;h>i;i++)if(c=d[i],!(!c.selected&&i!==e||(k.optDisabled?c.disabled:null!==c.getAttribute("disabled"))||c.parentNode.disabled&&m.nodeName(c.parentNode,"optgroup"))){if(b=m(c).val(),f)return b;g.push(b)}return g},set:function(a,b){var c,d,e=a.options,f=m.makeArray(b),g=e.length;while(g--)if(d=e[g],m.inArray(m.valHooks.option.get(d),f)>=0)try{d.selected=c=!0}catch(h){d.scrollHeight}else d.selected=!1;return c||(a.selectedIndex=-1),e}}}}),m.each(["radio","checkbox"],function(){m.valHooks[this]={set:function(a,b){return m.isArray(b)?a.checked=m.inArray(m(a).val(),b)>=0:void 0}},k.checkOn||(m.valHooks[this].get=function(a){return null===a.getAttribute("value")?"on":a.value})});var mc,nc,oc=m.expr.attrHandle,pc=/^(?:checked|selected)$/i,qc=k.getSetAttribute,rc=k.input;m.fn.extend({attr:function(a,b){return V(this,m.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){m.removeAttr(this,a)})}}),m.extend({attr:function(a,b,c){var d,e,f=a.nodeType;if(a&&3!==f&&8!==f&&2!==f)return typeof a.getAttribute===K?m.prop(a,b,c):(1===f&&m.isXMLDoc(a)||(b=b.toLowerCase(),d=m.attrHooks[b]||(m.expr.match.bool.test(b)?nc:mc)),void 0===c?d&&"get"in d&&null!==(e=d.get(a,b))?e:(e=m.find.attr(a,b),null==e?void 0:e):null!==c?d&&"set"in d&&void 0!==(e=d.set(a,c,b))?e:(a.setAttribute(b,c+""),c):void m.removeAttr(a,b))},removeAttr:function(a,b){var c,d,e=0,f=b&&b.match(E);if(f&&1===a.nodeType)while(c=f[e++])d=m.propFix[c]||c,m.expr.match.bool.test(c)?rc&&qc||!pc.test(c)?a[d]=!1:a[m.camelCase("default-"+c)]=a[d]=!1:m.attr(a,c,""),a.removeAttribute(qc?c:d)},attrHooks:{type:{set:function(a,b){if(!k.radioValue&&"radio"===b&&m.nodeName(a,"input")){var c=a.value;return a.setAttribute("type",b),c&&(a.value=c),b}}}}}),nc={set:function(a,b,c){return b===!1?m.removeAttr(a,c):rc&&qc||!pc.test(c)?a.setAttribute(!qc&&m.propFix[c]||c,c):a[m.camelCase("default-"+c)]=a[c]=!0,c}},m.each(m.expr.match.bool.source.match(/\w+/g),function(a,b){var c=oc[b]||m.find.attr;oc[b]=rc&&qc||!pc.test(b)?function(a,b,d){var e,f;return d||(f=oc[b],oc[b]=e,e=null!=c(a,b,d)?b.toLowerCase():null,oc[b]=f),e}:function(a,b,c){return c?void 0:a[m.camelCase("default-"+b)]?b.toLowerCase():null}}),rc&&qc||(m.attrHooks.value={set:function(a,b,c){return m.nodeName(a,"input")?void(a.defaultValue=b):mc&&mc.set(a,b,c)}}),qc||(mc={set:function(a,b,c){var d=a.getAttributeNode(c);return d||a.setAttributeNode(d=a.ownerDocument.createAttribute(c)),d.value=b+="","value"===c||b===a.getAttribute(c)?b:void 0}},oc.id=oc.name=oc.coords=function(a,b,c){var d;return c?void 0:(d=a.getAttributeNode(b))&&""!==d.value?d.value:null},m.valHooks.button={get:function(a,b){var c=a.getAttributeNode(b);return c&&c.specified?c.value:void 0},set:mc.set},m.attrHooks.contenteditable={set:function(a,b,c){mc.set(a,""===b?!1:b,c)}},m.each(["width","height"],function(a,b){m.attrHooks[b]={set:function(a,c){return""===c?(a.setAttribute(b,"auto"),c):void 0}}})),k.style||(m.attrHooks.style={get:function(a){return a.style.cssText||void 0},set:function(a,b){return a.style.cssText=b+""}});var sc=/^(?:input|select|textarea|button|object)$/i,tc=/^(?:a|area)$/i;m.fn.extend({prop:function(a,b){return V(this,m.prop,a,b,arguments.length>1)},removeProp:function(a){return a=m.propFix[a]||a,this.each(function(){try{this[a]=void 0,delete this[a]}catch(b){}})}}),m.extend({propFix:{"for":"htmlFor","class":"className"},prop:function(a,b,c){var d,e,f,g=a.nodeType;if(a&&3!==g&&8!==g&&2!==g)return f=1!==g||!m.isXMLDoc(a),f&&(b=m.propFix[b]||b,e=m.propHooks[b]),void 0!==c?e&&"set"in e&&void 0!==(d=e.set(a,c,b))?d:a[b]=c:e&&"get"in e&&null!==(d=e.get(a,b))?d:a[b]},propHooks:{tabIndex:{get:function(a){var b=m.find.attr(a,"tabindex");return b?parseInt(b,10):sc.test(a.nodeName)||tc.test(a.nodeName)&&a.href?0:-1}}}}),k.hrefNormalized||m.each(["href","src"],function(a,b){m.propHooks[b]={get:function(a){return a.getAttribute(b,4)}}}),k.optSelected||(m.propHooks.selected={get:function(a){var b=a.parentNode;return b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex),null}}),m.each(["tabIndex","readOnly","maxLength","cellSpacing","cellPadding","rowSpan","colSpan","useMap","frameBorder","contentEditable"],function(){m.propFix[this.toLowerCase()]=this}),k.enctype||(m.propFix.enctype="encoding");var uc=/[\t\r\n\f]/g;m.fn.extend({addClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j="string"==typeof a&&a;if(m.isFunction(a))return this.each(function(b){m(this).addClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):" ")){f=0;while(e=b[f++])d.indexOf(" "+e+" ")<0&&(d+=e+" ");g=m.trim(d),c.className!==g&&(c.className=g)}return this},removeClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j=0===arguments.length||"string"==typeof a&&a;if(m.isFunction(a))return this.each(function(b){m(this).removeClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):"")){f=0;while(e=b[f++])while(d.indexOf(" "+e+" ")>=0)d=d.replace(" "+e+" "," ");g=a?m.trim(d):"",c.className!==g&&(c.className=g)}return this},toggleClass:function(a,b){var c=typeof a;return"boolean"==typeof b&&"string"===c?b?this.addClass(a):this.removeClass(a):this.each(m.isFunction(a)?function(c){m(this).toggleClass(a.call(this,c,this.className,b),b)}:function(){if("string"===c){var b,d=0,e=m(this),f=a.match(E)||[];while(b=f[d++])e.hasClass(b)?e.removeClass(b):e.addClass(b)}else(c===K||"boolean"===c)&&(this.className&&m._data(this,"__className__",this.className),this.className=this.className||a===!1?"":m._data(this,"__className__")||"")})},hasClass:function(a){for(var b=" "+a+" ",c=0,d=this.length;d>c;c++)if(1===this[c].nodeType&&(" "+this[c].className+" ").replace(uc," ").indexOf(b)>=0)return!0;return!1}}),m.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){m.fn[b]=function(a,c){return arguments.length>0?this.on(b,null,a,c):this.trigger(b)}}),m.fn.extend({hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)},bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},delegate:function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return 1===arguments.length?this.off(a,"**"):this.off(b,a||"**",c)}});var vc=m.now(),wc=/\?/,xc=/(,)|(\[|{)|(}|])|"(?:[^"\\\r\n]|\\["\\\/bfnrt]|\\u[\da-fA-F]{4})*"\s*:?|true|false|null|-?(?!0\d)\d+(?:\.\d+|)(?:[eE][+-]?\d+|)/g;m.parseJSON=function(b){if(a.JSON&&a.JSON.parse)return a.JSON.parse(b+"");var c,d=null,e=m.trim(b+"");return e&&!m.trim(e.replace(xc,function(a,b,e,f){return c&&b&&(d=0),0===d?a:(c=e||b,d+=!f-!e,"")}))?Function("return "+e)():m.error("Invalid JSON: "+b)},m.parseXML=function(b){var c,d;if(!b||"string"!=typeof b)return null;try{a.DOMParser?(d=new DOMParser,c=d.parseFromString(b,"text/xml")):(c=new ActiveXObject("Microsoft.XMLDOM"),c.async="false",c.loadXML(b))}catch(e){c=void 0}return c&&c.documentElement&&!c.getElementsByTagName("parsererror").length||m.error("Invalid XML: "+b),c};var yc,zc,Ac=/#.*$/,Bc=/([?&])_=[^&]*/,Cc=/^(.*?):[ \t]*([^\r\n]*)\r?$/gm,Dc=/^(?:about|app|app-storage|.+-extension|file|res|widget):$/,Ec=/^(?:GET|HEAD)$/,Fc=/^\/\//,Gc=/^([\w.+-]+:)(?:\/\/(?:[^\/?#]*@|)([^\/?#:]*)(?::(\d+)|)|)/,Hc={},Ic={},Jc="*/".concat("*");try{zc=location.href}catch(Kc){zc=y.createElement("a"),zc.href="",zc=zc.href}yc=Gc.exec(zc.toLowerCase())||[];function Lc(a){return function(b,c){"string"!=typeof b&&(c=b,b="*");var d,e=0,f=b.toLowerCase().match(E)||[];if(m.isFunction(c))while(d=f[e++])"+"===d.charAt(0)?(d=d.slice(1)||"*",(a[d]=a[d]||[]).unshift(c)):(a[d]=a[d]||[]).push(c)}}function Mc(a,b,c,d){var e={},f=a===Ic;function g(h){var i;return e[h]=!0,m.each(a[h]||[],function(a,h){var j=h(b,c,d);return"string"!=typeof j||f||e[j]?f?!(i=j):void 0:(b.dataTypes.unshift(j),g(j),!1)}),i}return g(b.dataTypes[0])||!e["*"]&&g("*")}function Nc(a,b){var c,d,e=m.ajaxSettings.flatOptions||{};for(d in b)void 0!==b[d]&&((e[d]?a:c||(c={}))[d]=b[d]);return c&&m.extend(!0,a,c),a}function Oc(a,b,c){var d,e,f,g,h=a.contents,i=a.dataTypes;while("*"===i[0])i.shift(),void 0===e&&(e=a.mimeType||b.getResponseHeader("Content-Type"));if(e)for(g in h)if(h[g]&&h[g].test(e)){i.unshift(g);break}if(i[0]in c)f=i[0];else{for(g in c){if(!i[0]||a.converters[g+" "+i[0]]){f=g;break}d||(d=g)}f=f||d}return f?(f!==i[0]&&i.unshift(f),c[f]):void 0}function Pc(a,b,c,d){var e,f,g,h,i,j={},k=a.dataTypes.slice();if(k[1])for(g in a.converters)j[g.toLowerCase()]=a.converters[g];f=k.shift();while(f)if(a.responseFields[f]&&(c[a.responseFields[f]]=b),!i&&d&&a.dataFilter&&(b=a.dataFilter(b,a.dataType)),i=f,f=k.shift())if("*"===f)f=i;else if("*"!==i&&i!==f){if(g=j[i+" "+f]||j["* "+f],!g)for(e in j)if(h=e.split(" "),h[1]===f&&(g=j[i+" "+h[0]]||j["* "+h[0]])){g===!0?g=j[e]:j[e]!==!0&&(f=h[0],k.unshift(h[1]));break}if(g!==!0)if(g&&a["throws"])b=g(b);else try{b=g(b)}catch(l){return{state:"parsererror",error:g?l:"No conversion from "+i+" to "+f}}}return{state:"success",data:b}}m.extend({active:0,lastModified:{},etag:{},ajaxSettings:{url:zc,type:"GET",isLocal:Dc.test(yc[1]),global:!0,processData:!0,async:!0,contentType:"application/x-www-form-urlencoded; charset=UTF-8",accepts:{"*":Jc,text:"text/plain",html:"text/html",xml:"application/xml, text/xml",json:"application/json, text/javascript"},contents:{xml:/xml/,html:/html/,json:/json/},responseFields:{xml:"responseXML",text:"responseText",json:"responseJSON"},converters:{"* text":String,"text html":!0,"text json":m.parseJSON,"text xml":m.parseXML},flatOptions:{url:!0,context:!0}},ajaxSetup:function(a,b){return b?Nc(Nc(a,m.ajaxSettings),b):Nc(m.ajaxSettings,a)},ajaxPrefilter:Lc(Hc),ajaxTransport:Lc(Ic),ajax:function(a,b){"object"==typeof a&&(b=a,a=void 0),b=b||{};var c,d,e,f,g,h,i,j,k=m.ajaxSetup({},b),l=k.context||k,n=k.context&&(l.nodeType||l.jquery)?m(l):m.event,o=m.Deferred(),p=m.Callbacks("once memory"),q=k.statusCode||{},r={},s={},t=0,u="canceled",v={readyState:0,getResponseHeader:function(a){var b;if(2===t){if(!j){j={};while(b=Cc.exec(f))j[b[1].toLowerCase()]=b[2]}b=j[a.toLowerCase()]}return null==b?null:b},getAllResponseHeaders:function(){return 2===t?f:null},setRequestHeader:function(a,b){var c=a.toLowerCase();return t||(a=s[c]=s[c]||a,r[a]=b),this},overrideMimeType:function(a){return t||(k.mimeType=a),this},statusCode:function(a){var b;if(a)if(2>t)for(b in a)q[b]=[q[b],a[b]];else v.always(a[v.status]);return this},abort:function(a){var b=a||u;return i&&i.abort(b),x(0,b),this}};if(o.promise(v).complete=p.add,v.success=v.done,v.error=v.fail,k.url=((a||k.url||zc)+"").replace(Ac,"").replace(Fc,yc[1]+"//"),k.type=b.method||b.type||k.method||k.type,k.dataTypes=m.trim(k.dataType||"*").toLowerCase().match(E)||[""],null==k.crossDomain&&(c=Gc.exec(k.url.toLowerCase()),k.crossDomain=!(!c||c[1]===yc[1]&&c[2]===yc[2]&&(c[3]||("http:"===c[1]?"80":"443"))===(yc[3]||("http:"===yc[1]?"80":"443")))),k.data&&k.processData&&"string"!=typeof k.data&&(k.data=m.param(k.data,k.traditional)),Mc(Hc,k,b,v),2===t)return v;h=k.global,h&&0===m.active++&&m.event.trigger("ajaxStart"),k.type=k.type.toUpperCase(),k.hasContent=!Ec.test(k.type),e=k.url,k.hasContent||(k.data&&(e=k.url+=(wc.test(e)?"&":"?")+k.data,delete k.data),k.cache===!1&&(k.url=Bc.test(e)?e.replace(Bc,"$1_="+vc++):e+(wc.test(e)?"&":"?")+"_="+vc++)),k.ifModified&&(m.lastModified[e]&&v.setRequestHeader("If-Modified-Since",m.lastModified[e]),m.etag[e]&&v.setRequestHeader("If-None-Match",m.etag[e])),(k.data&&k.hasContent&&k.contentType!==!1||b.contentType)&&v.setRequestHeader("Content-Type",k.contentType),v.setRequestHeader("Accept",k.dataTypes[0]&&k.accepts[k.dataTypes[0]]?k.accepts[k.dataTypes[0]]+("*"!==k.dataTypes[0]?", "+Jc+"; q=0.01":""):k.accepts["*"]);for(d in k.headers)v.setRequestHeader(d,k.headers[d]);if(k.beforeSend&&(k.beforeSend.call(l,v,k)===!1||2===t))return v.abort();u="abort";for(d in{success:1,error:1,complete:1})v[d](k[d]);if(i=Mc(Ic,k,b,v)){v.readyState=1,h&&n.trigger("ajaxSend",[v,k]),k.async&&k.timeout>0&&(g=setTimeout(function(){v.abort("timeout")},k.timeout));try{t=1,i.send(r,x)}catch(w){if(!(2>t))throw w;x(-1,w)}}else x(-1,"No Transport");function x(a,b,c,d){var j,r,s,u,w,x=b;2!==t&&(t=2,g&&clearTimeout(g),i=void 0,f=d||"",v.readyState=a>0?4:0,j=a>=200&&300>a||304===a,c&&(u=Oc(k,v,c)),u=Pc(k,u,v,j),j?(k.ifModified&&(w=v.getResponseHeader("Last-Modified"),w&&(m.lastModified[e]=w),w=v.getResponseHeader("etag"),w&&(m.etag[e]=w)),204===a||"HEAD"===k.type?x="nocontent":304===a?x="notmodified":(x=u.state,r=u.data,s=u.error,j=!s)):(s=x,(a||!x)&&(x="error",0>a&&(a=0))),v.status=a,v.statusText=(b||x)+"",j?o.resolveWith(l,[r,x,v]):o.rejectWith(l,[v,x,s]),v.statusCode(q),q=void 0,h&&n.trigger(j?"ajaxSuccess":"ajaxError",[v,k,j?r:s]),p.fireWith(l,[v,x]),h&&(n.trigger("ajaxComplete",[v,k]),--m.active||m.event.trigger("ajaxStop")))}return v},getJSON:function(a,b,c){return m.get(a,b,c,"json")},getScript:function(a,b){return m.get(a,void 0,b,"script")}}),m.each(["get","post"],function(a,b){m[b]=function(a,c,d,e){return m.isFunction(c)&&(e=e||d,d=c,c=void 0),m.ajax({url:a,type:b,dataType:e,data:c,success:d})}}),m.each(["ajaxStart","ajaxStop","ajaxComplete","ajaxError","ajaxSuccess","ajaxSend"],function(a,b){m.fn[b]=function(a){return this.on(b,a)}}),m._evalUrl=function(a){return m.ajax({url:a,type:"GET",dataType:"script",async:!1,global:!1,"throws":!0})},m.fn.extend({wrapAll:function(a){if(m.isFunction(a))return this.each(function(b){m(this).wrapAll(a.call(this,b))});if(this[0]){var b=m(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;while(a.firstChild&&1===a.firstChild.nodeType)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){return this.each(m.isFunction(a)?function(b){m(this).wrapInner(a.call(this,b))}:function(){var b=m(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=m.isFunction(a);return this.each(function(c){m(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){m.nodeName(this,"body")||m(this).replaceWith(this.childNodes)}).end()}}),m.expr.filters.hidden=function(a){return a.offsetWidth<=0&&a.offsetHeight<=0||!k.reliableHiddenOffsets()&&"none"===(a.style&&a.style.display||m.css(a,"display"))},m.expr.filters.visible=function(a){return!m.expr.filters.hidden(a)};var Qc=/%20/g,Rc=/\[\]$/,Sc=/\r?\n/g,Tc=/^(?:submit|button|image|reset|file)$/i,Uc=/^(?:input|select|textarea|keygen)/i;function Vc(a,b,c,d){var e;if(m.isArray(b))m.each(b,function(b,e){c||Rc.test(a)?d(a,e):Vc(a+"["+("object"==typeof e?b:"")+"]",e,c,d)});else if(c||"object"!==m.type(b))d(a,b);else for(e in b)Vc(a+"["+e+"]",b[e],c,d)}m.param=function(a,b){var c,d=[],e=function(a,b){b=m.isFunction(b)?b():null==b?"":b,d[d.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};if(void 0===b&&(b=m.ajaxSettings&&m.ajaxSettings.traditional),m.isArray(a)||a.jquery&&!m.isPlainObject(a))m.each(a,function(){e(this.name,this.value)});else for(c in a)Vc(c,a[c],b,e);return d.join("&").replace(Qc,"+")},m.fn.extend({serialize:function(){return m.param(this.serializeArray())},serializeArray:function(){return this.map(function(){var a=m.prop(this,"elements");return a?m.makeArray(a):this}).filter(function(){var a=this.type;return this.name&&!m(this).is(":disabled")&&Uc.test(this.nodeName)&&!Tc.test(a)&&(this.checked||!W.test(a))}).map(function(a,b){var c=m(this).val();return null==c?null:m.isArray(c)?m.map(c,function(a){return{name:b.name,value:a.replace(Sc,"\r\n")}}):{name:b.name,value:c.replace(Sc,"\r\n")}}).get()}}),m.ajaxSettings.xhr=void 0!==a.ActiveXObject?function(){return!this.isLocal&&/^(get|post|head|put|delete|options)$/i.test(this.type)&&Zc()||$c()}:Zc;var Wc=0,Xc={},Yc=m.ajaxSettings.xhr();a.ActiveXObject&&m(a).on("unload",function(){for(var a in Xc)Xc[a](void 0,!0)}),k.cors=!!Yc&&"withCredentials"in Yc,Yc=k.ajax=!!Yc,Yc&&m.ajaxTransport(function(a){if(!a.crossDomain||k.cors){var b;return{send:function(c,d){var e,f=a.xhr(),g=++Wc;if(f.open(a.type,a.url,a.async,a.username,a.password),a.xhrFields)for(e in a.xhrFields)f[e]=a.xhrFields[e];a.mimeType&&f.overrideMimeType&&f.overrideMimeType(a.mimeType),a.crossDomain||c["X-Requested-With"]||(c["X-Requested-With"]="XMLHttpRequest");for(e in c)void 0!==c[e]&&f.setRequestHeader(e,c[e]+"");f.send(a.hasContent&&a.data||null),b=function(c,e){var h,i,j;if(b&&(e||4===f.readyState))if(delete Xc[g],b=void 0,f.onreadystatechange=m.noop,e)4!==f.readyState&&f.abort();else{j={},h=f.status,"string"==typeof f.responseText&&(j.text=f.responseText);try{i=f.statusText}catch(k){i=""}h||!a.isLocal||a.crossDomain?1223===h&&(h=204):h=j.text?200:404}j&&d(h,i,j,f.getAllResponseHeaders())},a.async?4===f.readyState?setTimeout(b):f.onreadystatechange=Xc[g]=b:b()},abort:function(){b&&b(void 0,!0)}}}});function Zc(){try{return new a.XMLHttpRequest}catch(b){}}function $c(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}m.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/(?:java|ecma)script/},converters:{"text script":function(a){return m.globalEval(a),a}}}),m.ajaxPrefilter("script",function(a){void 0===a.cache&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),m.ajaxTransport("script",function(a){if(a.crossDomain){var b,c=y.head||m("head")[0]||y.documentElement;return{send:function(d,e){b=y.createElement("script"),b.async=!0,a.scriptCharset&&(b.charset=a.scriptCharset),b.src=a.url,b.onload=b.onreadystatechange=function(a,c){(c||!b.readyState||/loaded|complete/.test(b.readyState))&&(b.onload=b.onreadystatechange=null,b.parentNode&&b.parentNode.removeChild(b),b=null,c||e(200,"success"))},c.insertBefore(b,c.firstChild)},abort:function(){b&&b.onload(void 0,!0)}}}});var _c=[],ad=/(=)\?(?=&|$)|\?\?/;m.ajaxSetup({jsonp:"callback",jsonpCallback:function(){var a=_c.pop()||m.expando+"_"+vc++;return this[a]=!0,a}}),m.ajaxPrefilter("json jsonp",function(b,c,d){var e,f,g,h=b.jsonp!==!1&&(ad.test(b.url)?"url":"string"==typeof b.data&&!(b.contentType||"").indexOf("application/x-www-form-urlencoded")&&ad.test(b.data)&&"data");return h||"jsonp"===b.dataTypes[0]?(e=b.jsonpCallback=m.isFunction(b.jsonpCallback)?b.jsonpCallback():b.jsonpCallback,h?b[h]=b[h].replace(ad,"$1"+e):b.jsonp!==!1&&(b.url+=(wc.test(b.url)?"&":"?")+b.jsonp+"="+e),b.converters["script json"]=function(){return g||m.error(e+" was not called"),g[0]},b.dataTypes[0]="json",f=a[e],a[e]=function(){g=arguments},d.always(function(){a[e]=f,b[e]&&(b.jsonpCallback=c.jsonpCallback,_c.push(e)),g&&m.isFunction(f)&&f(g[0]),g=f=void 0}),"script"):void 0}),m.parseHTML=function(a,b,c){if(!a||"string"!=typeof a)return null;"boolean"==typeof b&&(c=b,b=!1),b=b||y;var d=u.exec(a),e=!c&&[];return d?[b.createElement(d[1])]:(d=m.buildFragment([a],b,e),e&&e.length&&m(e).remove(),m.merge([],d.childNodes))};var bd=m.fn.load;m.fn.load=function(a,b,c){if("string"!=typeof a&&bd)return bd.apply(this,arguments);var d,e,f,g=this,h=a.indexOf(" ");return h>=0&&(d=m.trim(a.slice(h,a.length)),a=a.slice(0,h)),m.isFunction(b)?(c=b,b=void 0):b&&"object"==typeof b&&(f="POST"),g.length>0&&m.ajax({url:a,type:f,dataType:"html",data:b}).done(function(a){e=arguments,g.html(d?m("<div>").append(m.parseHTML(a)).find(d):a)}).complete(c&&function(a,b){g.each(c,e||[a.responseText,b,a])}),this},m.expr.filters.animated=function(a){return m.grep(m.timers,function(b){return a===b.elem}).length};var cd=a.document.documentElement;function dd(a){return m.isWindow(a)?a:9===a.nodeType?a.defaultView||a.parentWindow:!1}m.offset={setOffset:function(a,b,c){var d,e,f,g,h,i,j,k=m.css(a,"position"),l=m(a),n={};"static"===k&&(a.style.position="relative"),h=l.offset(),f=m.css(a,"top"),i=m.css(a,"left"),j=("absolute"===k||"fixed"===k)&&m.inArray("auto",[f,i])>-1,j?(d=l.position(),g=d.top,e=d.left):(g=parseFloat(f)||0,e=parseFloat(i)||0),m.isFunction(b)&&(b=b.call(a,c,h)),null!=b.top&&(n.top=b.top-h.top+g),null!=b.left&&(n.left=b.left-h.left+e),"using"in b?b.using.call(a,n):l.css(n)}},m.fn.extend({offset:function(a){if(arguments.length)return void 0===a?this:this.each(function(b){m.offset.setOffset(this,a,b)});var b,c,d={top:0,left:0},e=this[0],f=e&&e.ownerDocument;if(f)return b=f.documentElement,m.contains(b,e)?(typeof e.getBoundingClientRect!==K&&(d=e.getBoundingClientRect()),c=dd(f),{top:d.top+(c.pageYOffset||b.scrollTop)-(b.clientTop||0),left:d.left+(c.pageXOffset||b.scrollLeft)-(b.clientLeft||0)}):d},position:function(){if(this[0]){var a,b,c={top:0,left:0},d=this[0];return"fixed"===m.css(d,"position")?b=d.getBoundingClientRect():(a=this.offsetParent(),b=this.offset(),m.nodeName(a[0],"html")||(c=a.offset()),c.top+=m.css(a[0],"borderTopWidth",!0),c.left+=m.css(a[0],"borderLeftWidth",!0)),{top:b.top-c.top-m.css(d,"marginTop",!0),left:b.left-c.left-m.css(d,"marginLeft",!0)}}},offsetParent:function(){return this.map(function(){var a=this.offsetParent||cd;while(a&&!m.nodeName(a,"html")&&"static"===m.css(a,"position"))a=a.offsetParent;return a||cd})}}),m.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,b){var c=/Y/.test(b);m.fn[a]=function(d){return V(this,function(a,d,e){var f=dd(a);return void 0===e?f?b in f?f[b]:f.document.documentElement[d]:a[d]:void(f?f.scrollTo(c?m(f).scrollLeft():e,c?e:m(f).scrollTop()):a[d]=e)},a,d,arguments.length,null)}}),m.each(["top","left"],function(a,b){m.cssHooks[b]=Lb(k.pixelPosition,function(a,c){return c?(c=Jb(a,b),Hb.test(c)?m(a).position()[b]+"px":c):void 0})}),m.each({Height:"height",Width:"width"},function(a,b){m.each({padding:"inner"+a,content:b,"":"outer"+a},function(c,d){m.fn[d]=function(d,e){var f=arguments.length&&(c||"boolean"!=typeof d),g=c||(d===!0||e===!0?"margin":"border");return V(this,function(b,c,d){var e;return m.isWindow(b)?b.document.documentElement["client"+a]:9===b.nodeType?(e=b.documentElement,Math.max(b.body["scroll"+a],e["scroll"+a],b.body["offset"+a],e["offset"+a],e["client"+a])):void 0===d?m.css(b,c,g):m.style(b,c,d,g)},b,f?d:void 0,f,null)}})}),m.fn.size=function(){return this.length},m.fn.andSelf=m.fn.addBack,"function"==typeof define&&define.amd&&define("jquery",[],function(){return m});var ed=a.jQuery,fd=a.$;return m.noConflict=function(b){return a.$===m&&(a.$=fd),b&&a.jQuery===m&&(a.jQuery=ed),m},typeof b===K&&(a.jQuery=a.$=m),m});

/**
 * jscolor, JavaScript Color Picker
 *
 * @version 1.4.5
 * @license GNU Lesser General Public License, http://www.gnu.org/copyleft/lesser.html
 * @author  Jan Odvarko, http://odvarko.cz
 * @created 2008-06-15
 * @updated 2015-09-19
 * @link    http://jscolor.com
 */

 
var jscolor = {


	dir : '', // location of jscolor directory (leave empty to autodetect)
	bindClass : 'color', // class name
	binding : true, // automatic binding via <input class="...">
	preloading : true, // use image preloading?


	install : function() {
		jscolor.addEvent(window, 'load', jscolor.init);
	},


	init : function() {
		if(jscolor.binding) {
			jscolor.bind();
		}
		if(jscolor.preloading) {
			jscolor.preload();
		}
	},


	getDir : function() {
		if(!jscolor.dir) {
			var detected = jscolor.detectDir();
			jscolor.dir = detected!==false ? detected : 'jscolor/';
		}
		return jscolor.dir;
	},


	detectDir : function() {
		var base = location.href;

		var e = document.getElementsByTagName('base');
		for(var i=0; i<e.length; i+=1) {
			if(e[i].href) { base = e[i].href; }
		}

		var e = document.getElementsByTagName('script');
		for(var i=0; i<e.length; i+=1) {
			if(e[i].src && /(^|\/)jscolor\.js([?#].*)?$/i.test(e[i].src)) {
				var src = new jscolor.URI(e[i].src);
				var srcAbs = src.toAbsolute(base);
				srcAbs.path = srcAbs.path.replace(/[^\/]+$/, ''); // remove filename
				srcAbs.query = null;
				srcAbs.fragment = null;
				return srcAbs.toString();
			}
		}
		return false;
	},


	bind : function() {
		var matchClass = new RegExp('(^|\\s)('+jscolor.bindClass+')(\\s*(\\{[^}]*\\})|\\s|$)', 'i');
		var e = document.getElementsByTagName('input');
		for(var i=0; i<e.length; i+=1) {
			if(jscolor.isColorAttrSupported && e[i].type.toLowerCase() == 'color') {
				// skip inputs of type 'color' if the browser supports this feature
				continue;
			}
			var m;
			if(!e[i].color && e[i].className && (m = e[i].className.match(matchClass))) {
				var prop = {};
				if(m[4]) {
					try {
						prop = (new Function ('return (' + m[4] + ')'))();
					} catch(eInvalidProp) {}
				}
				e[i].color = new jscolor.color(e[i], prop);
			}
		}
	},


	preload : function() {
		for(var fn in jscolor.imgRequire) {
			if(jscolor.imgRequire.hasOwnProperty(fn)) {
				jscolor.loadImage(fn);
			}
		}
	},


	images : {
		pad : [ 181, 101 ],
		sld : [ 16, 101 ],
		cross : [ 15, 15 ],
		arrow : [ 7, 11 ]
	},


	imgRequire : {},
	imgLoaded : {},


	requireImage : function(filename) {
		jscolor.imgRequire[filename] = true;
	},


	loadImage : function(filename) {
		if(!jscolor.imgLoaded[filename]) {
			jscolor.imgLoaded[filename] = new Image();
			jscolor.imgLoaded[filename].src = jscolor.getDir()+filename;
		}
	},


	fetchElement : function(mixed) {
		return typeof mixed === 'string' ? document.getElementById(mixed) : mixed;
	},


	addEvent : function(el, evnt, func) {
		if(el.addEventListener) {
			el.addEventListener(evnt, func, false);
		} else if(el.attachEvent) {
			el.attachEvent('on'+evnt, func);
		}
	},


	fireEvent : function(el, evnt) {
		if(!el) {
			return;
		}
		if(document.createEvent) {
			var ev = document.createEvent('HTMLEvents');
			ev.initEvent(evnt, true, true);
			el.dispatchEvent(ev);
		} else if(document.createEventObject) {
			var ev = document.createEventObject();
			el.fireEvent('on'+evnt, ev);
		} else if(el['on'+evnt]) { // alternatively use the traditional event model (IE5)
			el['on'+evnt]();
		}
	},


	getElementPos : function(e) {
		var e1=e, e2=e;
		var x=0, y=0;
		if(e1.offsetParent) {
			do {
				x += e1.offsetLeft;
				y += e1.offsetTop;
			} while(e1 = e1.offsetParent);
		}
		while((e2 = e2.parentNode) && e2.nodeName.toUpperCase() !== 'BODY') {
			x -= e2.scrollLeft;
			y -= e2.scrollTop;
		}
		return [x, y];
	},


	getElementSize : function(e) {
		return [e.offsetWidth, e.offsetHeight];
	},


	getRelMousePos : function(e) {
		var x = 0, y = 0;
		if (!e) { e = window.event; }
		if (typeof e.offsetX === 'number') {
			x = e.offsetX;
			y = e.offsetY;
		} else if (typeof e.layerX === 'number') {
			x = e.layerX;
			y = e.layerY;
		}
		return { x: x, y: y };
	},


	getViewPos : function() {
		if(typeof window.pageYOffset === 'number') {
			return [window.pageXOffset, window.pageYOffset];
		} else if(document.body && (document.body.scrollLeft || document.body.scrollTop)) {
			return [document.body.scrollLeft, document.body.scrollTop];
		} else if(document.documentElement && (document.documentElement.scrollLeft || document.documentElement.scrollTop)) {
			return [document.documentElement.scrollLeft, document.documentElement.scrollTop];
		} else {
			return [0, 0];
		}
	},


	getViewSize : function() {
		if(typeof window.innerWidth === 'number') {
			return [window.innerWidth, window.innerHeight];
		} else if(document.body && (document.body.clientWidth || document.body.clientHeight)) {
			return [document.body.clientWidth, document.body.clientHeight];
		} else if(document.documentElement && (document.documentElement.clientWidth || document.documentElement.clientHeight)) {
			return [document.documentElement.clientWidth, document.documentElement.clientHeight];
		} else {
			return [0, 0];
		}
	},


	URI : function(uri) { // See RFC3986

		this.scheme = null;
		this.authority = null;
		this.path = '';
		this.query = null;
		this.fragment = null;

		this.parse = function(uri) {
			var m = uri.match(/^(([A-Za-z][0-9A-Za-z+.-]*)(:))?((\/\/)([^\/?#]*))?([^?#]*)((\?)([^#]*))?((#)(.*))?/);
			this.scheme = m[3] ? m[2] : null;
			this.authority = m[5] ? m[6] : null;
			this.path = m[7];
			this.query = m[9] ? m[10] : null;
			this.fragment = m[12] ? m[13] : null;
			return this;
		};

		this.toString = function() {
			var result = '';
			if(this.scheme !== null) { result = result + this.scheme + ':'; }
			if(this.authority !== null) { result = result + '//' + this.authority; }
			if(this.path !== null) { result = result + this.path; }
			if(this.query !== null) { result = result + '?' + this.query; }
			if(this.fragment !== null) { result = result + '#' + this.fragment; }
			return result;
		};

		this.toAbsolute = function(base) {
			var base = new jscolor.URI(base);
			var r = this;
			var t = new jscolor.URI;

			if(base.scheme === null) { return false; }

			if(r.scheme !== null && r.scheme.toLowerCase() === base.scheme.toLowerCase()) {
				r.scheme = null;
			}

			if(r.scheme !== null) {
				t.scheme = r.scheme;
				t.authority = r.authority;
				t.path = removeDotSegments(r.path);
				t.query = r.query;
			} else {
				if(r.authority !== null) {
					t.authority = r.authority;
					t.path = removeDotSegments(r.path);
					t.query = r.query;
				} else {
					if(r.path === '') {
						t.path = base.path;
						if(r.query !== null) {
							t.query = r.query;
						} else {
							t.query = base.query;
						}
					} else {
						if(r.path.substr(0,1) === '/') {
							t.path = removeDotSegments(r.path);
						} else {
							if(base.authority !== null && base.path === '') {
								t.path = '/'+r.path;
							} else {
								t.path = base.path.replace(/[^\/]+$/,'')+r.path;
							}
							t.path = removeDotSegments(t.path);
						}
						t.query = r.query;
					}
					t.authority = base.authority;
				}
				t.scheme = base.scheme;
			}
			t.fragment = r.fragment;

			return t;
		};

		function removeDotSegments(path) {
			var out = '';
			while(path) {
				if(path.substr(0,3)==='../' || path.substr(0,2)==='./') {
					path = path.replace(/^\.+/,'').substr(1);
				} else if(path.substr(0,3)==='/./' || path==='/.') {
					path = '/'+path.substr(3);
				} else if(path.substr(0,4)==='/../' || path==='/..') {
					path = '/'+path.substr(4);
					out = out.replace(/\/?[^\/]*$/, '');
				} else if(path==='.' || path==='..') {
					path = '';
				} else {
					var rm = path.match(/^\/?[^\/]*/)[0];
					path = path.substr(rm.length);
					out = out + rm;
				}
			}
			return out;
		}

		if(uri) {
			this.parse(uri);
		}

	},


	//
	// Usage example:
	// var myColor = new jscolor.color(myInputElement)
	//

	color : function(target, prop) {


		this.required = true; // refuse empty values?
		this.adjust = true; // adjust value to uniform notation?
		this.hash = false; // prefix color with # symbol?
		this.caps = true; // uppercase?
		this.slider = true; // show the value/saturation slider?
		this.valueElement = target; // value holder
		this.styleElement = target; // where to reflect current color
		this.onImmediateChange = null; // onchange callback (can be either string or function)
		this.hsv = [0, 0, 1]; // read-only  0-6, 0-1, 0-1
		this.rgb = [1, 1, 1]; // read-only  0-1, 0-1, 0-1
		this.minH = 0; // read-only  0-6
		this.maxH = 6; // read-only  0-6
		this.minS = 0; // read-only  0-1
		this.maxS = 1; // read-only  0-1
		this.minV = 0; // read-only  0-1
		this.maxV = 1; // read-only  0-1

		this.pickerOnfocus = true; // display picker on focus?
		this.pickerMode = 'HSV'; // HSV | HVS
		this.pickerPosition = 'bottom'; // left | right | top | bottom
		this.pickerSmartPosition = true; // automatically adjust picker position when necessary
		this.pickerFixedPosition = false; // set to true to stop picker from moving on scroll
		this.pickerButtonHeight = 20; // px
		this.pickerClosable = false;
		this.pickerCloseText = 'Close';
		this.pickerButtonColor = 'ButtonText'; // px
		this.pickerFace = 10; // px
		this.pickerFaceColor = 'ThreeDFace'; // CSS color
		this.pickerBorder = 1; // px
		this.pickerBorderColor = 'ThreeDHighlight ThreeDShadow ThreeDShadow ThreeDHighlight'; // CSS color
		this.pickerInset = 1; // px
		this.pickerInsetColor = 'ThreeDShadow ThreeDHighlight ThreeDHighlight ThreeDShadow'; // CSS color
		this.pickerZIndex = 10000;


		for(var p in prop) {
			if(prop.hasOwnProperty(p)) {
				this[p] = prop[p];
			}
		}


		this.hidePicker = function() {
			if(isPickerOwner()) {
				removePicker();
			}
		};


		this.showPicker = function() {
			if(!isPickerOwner()) {
				var tp = jscolor.getElementPos(target); // target pos
				var ts = jscolor.getElementSize(target); // target size
				var vp = jscolor.getViewPos(); // view pos
				var vs = jscolor.getViewSize(); // view size
				var ps = getPickerDims(this); // picker size
				var a, b, c;
				switch(this.pickerPosition.toLowerCase()) {
					case 'left': a=1; b=0; c=-1; break;
					case 'right':a=1; b=0; c=1; break;
					case 'top':  a=0; b=1; c=-1; break;
					default:     a=0; b=1; c=1; break;
				}
				var l = (ts[b]+ps[b])/2;

				// picker pos
				if (!this.pickerSmartPosition) {
					var pp = [
						tp[a],
						tp[b]+ts[b]-l+l*c
					];
				} else {
					var pp = [
						-vp[a]+tp[a]+ps[a] > vs[a] ?
							(-vp[a]+tp[a]+ts[a]/2 > vs[a]/2 && tp[a]+ts[a]-ps[a] >= 0 ? tp[a]+ts[a]-ps[a] : tp[a]) :
							tp[a],
						-vp[b]+tp[b]+ts[b]+ps[b]-l+l*c > vs[b] ?
							(-vp[b]+tp[b]+ts[b]/2 > vs[b]/2 && tp[b]+ts[b]-l-l*c >= 0 ? tp[b]+ts[b]-l-l*c : tp[b]+ts[b]-l+l*c) :
							(tp[b]+ts[b]-l+l*c >= 0 ? tp[b]+ts[b]-l+l*c : tp[b]+ts[b]-l-l*c)
					];
				}
				drawPicker(pp[a], pp[b]);
			}
		};


		this.importColor = function() {
			if(!valueElement) {
				this.exportColor();
			} else {
				if(!this.adjust) {
					if(!this.fromString(valueElement.value, leaveValue)) {
						styleElement.style.backgroundImage = styleElement.jscStyle.backgroundImage;
						styleElement.style.backgroundColor = styleElement.jscStyle.backgroundColor;
						styleElement.style.color = styleElement.jscStyle.color;
						this.exportColor(leaveValue | leaveStyle);
					}
				} else if(!this.required && /^\s*$/.test(valueElement.value)) {
					valueElement.value = '';
					styleElement.style.backgroundImage = styleElement.jscStyle.backgroundImage;
					styleElement.style.backgroundColor = styleElement.jscStyle.backgroundColor;
					styleElement.style.color = styleElement.jscStyle.color;
					this.exportColor(leaveValue | leaveStyle);

				} else if(this.fromString(valueElement.value)) {
					// OK
				} else {
					this.exportColor();
				}
			}
		};


		this.exportColor = function(flags) {
			if(!(flags & leaveValue) && valueElement) {
				var value = this.toString();
				if(this.caps) { value = value.toUpperCase(); }
				if(this.hash) { value = '#'+value; }
				valueElement.value = value;
			}
			if(!(flags & leaveStyle) && styleElement) {
				styleElement.style.backgroundImage = "none";
				styleElement.style.backgroundColor =
					'#'+this.toString();
				styleElement.style.color =
					0.213 * this.rgb[0] +
					0.715 * this.rgb[1] +
					0.072 * this.rgb[2]
					< 0.5 ? '#FFF' : '#000';
			}
			if(!(flags & leavePad) && isPickerOwner()) {
				redrawPad();
			}
			if(!(flags & leaveSld) && isPickerOwner()) {
				redrawSld();
			}
		};


		this.fromHSV = function(h, s, v, flags) { // null = don't change
			if(h !== null) { h = Math.max(0.0, this.minH, Math.min(6.0, this.maxH, h)); }
			if(s !== null) { s = Math.max(0.0, this.minS, Math.min(1.0, this.maxS, s)); }
			if(v !== null) { v = Math.max(0.0, this.minV, Math.min(1.0, this.maxV, v)); }

			this.rgb = HSV_RGB(
				h===null ? this.hsv[0] : (this.hsv[0]=h),
				s===null ? this.hsv[1] : (this.hsv[1]=s),
				v===null ? this.hsv[2] : (this.hsv[2]=v)
			);

			this.exportColor(flags);
		};


		this.fromRGB = function(r, g, b, flags) { // null = don't change
			if(r !== null) { r = Math.max(0.0, Math.min(1.0, r)); }
			if(g !== null) { g = Math.max(0.0, Math.min(1.0, g)); }
			if(b !== null) { b = Math.max(0.0, Math.min(1.0, b)); }

			var hsv = RGB_HSV(
				r===null ? this.rgb[0] : r,
				g===null ? this.rgb[1] : g,
				b===null ? this.rgb[2] : b
			);
			if(hsv[0] !== null) {
				this.hsv[0] = Math.max(0.0, this.minH, Math.min(6.0, this.maxH, hsv[0]));
			}
			if(hsv[2] !== 0) {
				this.hsv[1] = hsv[1]===null ? null : Math.max(0.0, this.minS, Math.min(1.0, this.maxS, hsv[1]));
			}
			this.hsv[2] = hsv[2]===null ? null : Math.max(0.0, this.minV, Math.min(1.0, this.maxV, hsv[2]));

			// update RGB according to final HSV, as some values might be trimmed
			var rgb = HSV_RGB(this.hsv[0], this.hsv[1], this.hsv[2]);
			this.rgb[0] = rgb[0];
			this.rgb[1] = rgb[1];
			this.rgb[2] = rgb[2];

			this.exportColor(flags);
		};


		this.fromString = function(hex, flags) {
			var m = hex.match(/^\W*([0-9A-F]{3}([0-9A-F]{3})?)\W*$/i);
			if(!m) {
				return false;
			} else {
				if(m[1].length === 6) { // 6-char notation
					this.fromRGB(
						parseInt(m[1].substr(0,2),16) / 255,
						parseInt(m[1].substr(2,2),16) / 255,
						parseInt(m[1].substr(4,2),16) / 255,
						flags
					);
				} else { // 3-char notation
					this.fromRGB(
						parseInt(m[1].charAt(0)+m[1].charAt(0),16) / 255,
						parseInt(m[1].charAt(1)+m[1].charAt(1),16) / 255,
						parseInt(m[1].charAt(2)+m[1].charAt(2),16) / 255,
						flags
					);
				}
				return true;
			}
		};


		this.toString = function() {
			return (
				(0x100 | Math.round(255*this.rgb[0])).toString(16).substr(1) +
				(0x100 | Math.round(255*this.rgb[1])).toString(16).substr(1) +
				(0x100 | Math.round(255*this.rgb[2])).toString(16).substr(1)
			);
		};


		function RGB_HSV(r, g, b) {
			var n = Math.min(Math.min(r,g),b);
			var v = Math.max(Math.max(r,g),b);
			var m = v - n;
			if(m === 0) { return [ null, 0, v ]; }
			var h = r===n ? 3+(b-g)/m : (g===n ? 5+(r-b)/m : 1+(g-r)/m);
			return [ h===6?0:h, m/v, v ];
		}


		function HSV_RGB(h, s, v) {
			if(h === null) { return [ v, v, v ]; }
			var i = Math.floor(h);
			var f = i%2 ? h-i : 1-(h-i);
			var m = v * (1 - s);
			var n = v * (1 - s*f);
			switch(i) {
				case 6:
				case 0: return [v,n,m];
				case 1: return [n,v,m];
				case 2: return [m,v,n];
				case 3: return [m,n,v];
				case 4: return [n,m,v];
				case 5: return [v,m,n];
			}
		}


		function removePicker() {
			delete jscolor.picker.owner;
			document.getElementsByTagName('body')[0].removeChild(jscolor.picker.boxB);
		}


		function drawPicker(x, y) {
			if(!jscolor.picker) {
				jscolor.picker = {
					box : document.createElement('div'),
					boxB : document.createElement('div'),
					pad : document.createElement('div'),
					padB : document.createElement('div'),
					padM : document.createElement('div'),
					sld : document.createElement('div'),
					sldB : document.createElement('div'),
					sldM : document.createElement('div'),
					btn : document.createElement('div'),
					btnS : document.createElement('span'),
					btnT : document.createTextNode(THIS.pickerCloseText)
				};
				for(var i=0,segSize=4; i<jscolor.images.sld[1]; i+=segSize) {
					var seg = document.createElement('div');
					seg.style.height = segSize+'px';
					seg.style.fontSize = '1px';
					seg.style.lineHeight = '0';
					jscolor.picker.sld.appendChild(seg);
				}
				jscolor.picker.sldB.appendChild(jscolor.picker.sld);
				jscolor.picker.box.appendChild(jscolor.picker.sldB);
				jscolor.picker.box.appendChild(jscolor.picker.sldM);
				jscolor.picker.padB.appendChild(jscolor.picker.pad);
				jscolor.picker.box.appendChild(jscolor.picker.padB);
				jscolor.picker.box.appendChild(jscolor.picker.padM);
				jscolor.picker.btnS.appendChild(jscolor.picker.btnT);
				jscolor.picker.btn.appendChild(jscolor.picker.btnS);
				jscolor.picker.box.appendChild(jscolor.picker.btn);
				jscolor.picker.boxB.appendChild(jscolor.picker.box);
			}

			var p = jscolor.picker;

			// controls interaction
			p.box.onmouseup =
			p.box.onmouseout = function() { target.focus(); };
			p.box.onmousedown = function() { abortBlur=true; };
			p.box.onmousemove = function(e) {
				if (holdPad || holdSld) {
					holdPad && setPad(e);
					holdSld && setSld(e);
					if (document.selection) {
						document.selection.empty();
					} else if (window.getSelection) {
						window.getSelection().removeAllRanges();
					}
					dispatchImmediateChange();
				}
			};
			if('ontouchstart' in window) { // if touch device
				var handle_touchmove = function(e) {
					var event={
						'offsetX': e.touches[0].pageX-touchOffset.X,
						'offsetY': e.touches[0].pageY-touchOffset.Y
					};
					if (holdPad || holdSld) {
						holdPad && setPad(event);
						holdSld && setSld(event);
						dispatchImmediateChange();
					}
					e.stopPropagation(); // prevent move "view" on broswer
					e.preventDefault(); // prevent Default - Android Fix (else android generated only 1-2 touchmove events)
				};
				p.box.removeEventListener('touchmove', handle_touchmove, false)
				p.box.addEventListener('touchmove', handle_touchmove, false)
			}
			p.padM.onmouseup =
			p.padM.onmouseout = function() { if(holdPad) { holdPad=false; jscolor.fireEvent(valueElement,'change'); } };
			p.padM.onmousedown = function(e) {
				// if the slider is at the bottom, move it up
				switch(modeID) {
					case 0: if (THIS.hsv[2] === 0) { THIS.fromHSV(null, null, 1.0); }; break;
					case 1: if (THIS.hsv[1] === 0) { THIS.fromHSV(null, 1.0, null); }; break;
				}
				holdSld=false;
				holdPad=true;
				setPad(e);
				dispatchImmediateChange();
			};
			if('ontouchstart' in window) {
				p.padM.addEventListener('touchstart', function(e) {
					touchOffset={
						'X': e.target.offsetParent.offsetLeft,
						'Y': e.target.offsetParent.offsetTop
					};
					this.onmousedown({
						'offsetX':e.touches[0].pageX-touchOffset.X,
						'offsetY':e.touches[0].pageY-touchOffset.Y
					});
				});
			}
			p.sldM.onmouseup =
			p.sldM.onmouseout = function() { if(holdSld) { holdSld=false; jscolor.fireEvent(valueElement,'change'); } };
			p.sldM.onmousedown = function(e) {
				holdPad=false;
				holdSld=true;
				setSld(e);
				dispatchImmediateChange();
			};
			if('ontouchstart' in window) {
				p.sldM.addEventListener('touchstart', function(e) {
					touchOffset={
						'X': e.target.offsetParent.offsetLeft,
						'Y': e.target.offsetParent.offsetTop
					};
					this.onmousedown({
						'offsetX':e.touches[0].pageX-touchOffset.X,
						'offsetY':e.touches[0].pageY-touchOffset.Y
					});
				});
			}

			// picker
			var dims = getPickerDims(THIS);
			p.box.style.width = dims[0] + 'px';
			p.box.style.height = dims[1] + 'px';

			// picker border
			p.boxB.style.position = THIS.pickerFixedPosition ? 'fixed' : 'absolute';
			p.boxB.style.clear = 'both';
			p.boxB.style.left = x+'px';
			p.boxB.style.top = y+'px';
			p.boxB.style.zIndex = THIS.pickerZIndex;
			p.boxB.style.border = THIS.pickerBorder+'px solid';
			p.boxB.style.borderColor = THIS.pickerBorderColor;
			p.boxB.style.background = THIS.pickerFaceColor;

			// pad image
			p.pad.style.width = jscolor.images.pad[0]+'px';
			p.pad.style.height = jscolor.images.pad[1]+'px';

			// pad border
			p.padB.style.position = 'absolute';
			p.padB.style.left = THIS.pickerFace+'px';
			p.padB.style.top = THIS.pickerFace+'px';
			p.padB.style.border = THIS.pickerInset+'px solid';
			p.padB.style.borderColor = THIS.pickerInsetColor;

			// pad mouse area
			p.padM.style.position = 'absolute';
			p.padM.style.left = '0';
			p.padM.style.top = '0';
			p.padM.style.width = THIS.pickerFace + 2*THIS.pickerInset + jscolor.images.pad[0] + jscolor.images.arrow[0] + 'px';
			p.padM.style.height = p.box.style.height;
			p.padM.style.cursor = 'crosshair';

			// slider image
			p.sld.style.overflow = 'hidden';
			p.sld.style.width = jscolor.images.sld[0]+'px';
			p.sld.style.height = jscolor.images.sld[1]+'px';

			// slider border
			p.sldB.style.display = THIS.slider ? 'block' : 'none';
			p.sldB.style.position = 'absolute';
			p.sldB.style.right = THIS.pickerFace+'px';
			p.sldB.style.top = THIS.pickerFace+'px';
			p.sldB.style.border = THIS.pickerInset+'px solid';
			p.sldB.style.borderColor = THIS.pickerInsetColor;

			// slider mouse area
			p.sldM.style.display = THIS.slider ? 'block' : 'none';
			p.sldM.style.position = 'absolute';
			p.sldM.style.right = '0';
			p.sldM.style.top = '0';
			p.sldM.style.width = jscolor.images.sld[0] + jscolor.images.arrow[0] + THIS.pickerFace + 2*THIS.pickerInset + 'px';
			p.sldM.style.height = p.box.style.height;
			try {
				p.sldM.style.cursor = 'pointer';
			} catch(eOldIE) {
				p.sldM.style.cursor = 'hand';
			}

			// "close" button
			function setBtnBorder() {
				var insetColors = THIS.pickerInsetColor.split(/\s+/);
				var pickerOutsetColor = insetColors.length < 2 ? insetColors[0] : insetColors[1] + ' ' + insetColors[0] + ' ' + insetColors[0] + ' ' + insetColors[1];
				p.btn.style.borderColor = pickerOutsetColor;
			}
			p.btn.style.display = THIS.pickerClosable ? 'block' : 'none';
			p.btn.style.position = 'absolute';
			p.btn.style.left = THIS.pickerFace + 'px';
			p.btn.style.bottom = THIS.pickerFace + 'px';
			p.btn.style.padding = '0 15px';
			p.btn.style.height = '18px';
			p.btn.style.border = THIS.pickerInset + 'px solid';
			setBtnBorder();
			p.btn.style.color = THIS.pickerButtonColor;
			p.btn.style.font = '12px sans-serif';
			p.btn.style.textAlign = 'center';
			try {
				p.btn.style.cursor = 'pointer';
			} catch(eOldIE) {
				p.btn.style.cursor = 'hand';
			}
			p.btn.onmousedown = function () {
				THIS.hidePicker();
			};
			p.btnS.style.lineHeight = p.btn.style.height;

			// load images in optimal order
			switch(modeID) {
				case 0: var padImg = 'hs.png'; break;
				case 1: var padImg = 'hv.png'; break;
			}
			p.padM.style.backgroundImage = "url('"+jscolor.getDir()+"cross.gif')";
			p.padM.style.backgroundRepeat = "no-repeat";
			p.sldM.style.backgroundImage = "url('"+jscolor.getDir()+"arrow.gif')";
			p.sldM.style.backgroundRepeat = "no-repeat";
			p.pad.style.backgroundImage = "url('"+jscolor.getDir()+padImg+"')";
			p.pad.style.backgroundRepeat = "no-repeat";
			p.pad.style.backgroundPosition = "0 0";

			// place pointers
			redrawPad();
			redrawSld();

			jscolor.picker.owner = THIS;
			document.getElementsByTagName('body')[0].appendChild(p.boxB);
		}


		function getPickerDims(o) {
			var dims = [
				2*o.pickerInset + 2*o.pickerFace + jscolor.images.pad[0] +
					(o.slider ? 2*o.pickerInset + 2*jscolor.images.arrow[0] + jscolor.images.sld[0] : 0),
				o.pickerClosable ?
					4*o.pickerInset + 3*o.pickerFace + jscolor.images.pad[1] + o.pickerButtonHeight :
					2*o.pickerInset + 2*o.pickerFace + jscolor.images.pad[1]
			];
			return dims;
		}


		function redrawPad() {
			// redraw the pad pointer
			switch(modeID) {
				case 0: var yComponent = 1; break;
				case 1: var yComponent = 2; break;
			}
			var x = Math.round((THIS.hsv[0]/6) * (jscolor.images.pad[0]-1));
			var y = Math.round((1-THIS.hsv[yComponent]) * (jscolor.images.pad[1]-1));
			jscolor.picker.padM.style.backgroundPosition =
				(THIS.pickerFace+THIS.pickerInset+x - Math.floor(jscolor.images.cross[0]/2)) + 'px ' +
				(THIS.pickerFace+THIS.pickerInset+y - Math.floor(jscolor.images.cross[1]/2)) + 'px';

			// redraw the slider image
			var seg = jscolor.picker.sld.childNodes;

			switch(modeID) {
				case 0:
					var rgb = HSV_RGB(THIS.hsv[0], THIS.hsv[1], 1);
					for(var i=0; i<seg.length; i+=1) {
						seg[i].style.backgroundColor = 'rgb('+
							(rgb[0]*(1-i/seg.length)*100)+'%,'+
							(rgb[1]*(1-i/seg.length)*100)+'%,'+
							(rgb[2]*(1-i/seg.length)*100)+'%)';
					}
					break;
				case 1:
					var rgb, s, c = [ THIS.hsv[2], 0, 0 ];
					var i = Math.floor(THIS.hsv[0]);
					var f = i%2 ? THIS.hsv[0]-i : 1-(THIS.hsv[0]-i);
					switch(i) {
						case 6:
						case 0: rgb=[0,1,2]; break;
						case 1: rgb=[1,0,2]; break;
						case 2: rgb=[2,0,1]; break;
						case 3: rgb=[2,1,0]; break;
						case 4: rgb=[1,2,0]; break;
						case 5: rgb=[0,2,1]; break;
					}
					for(var i=0; i<seg.length; i+=1) {
						s = 1 - 1/(seg.length-1)*i;
						c[1] = c[0] * (1 - s*f);
						c[2] = c[0] * (1 - s);
						seg[i].style.backgroundColor = 'rgb('+
							(c[rgb[0]]*100)+'%,'+
							(c[rgb[1]]*100)+'%,'+
							(c[rgb[2]]*100)+'%)';
					}
					break;
			}
		}


		function redrawSld() {
			// redraw the slider pointer
			switch(modeID) {
				case 0: var yComponent = 2; break;
				case 1: var yComponent = 1; break;
			}
			var y = Math.round((1-THIS.hsv[yComponent]) * (jscolor.images.sld[1]-1));
			jscolor.picker.sldM.style.backgroundPosition =
				'0 ' + (THIS.pickerFace+THIS.pickerInset+y - Math.floor(jscolor.images.arrow[1]/2)) + 'px';
		}


		function isPickerOwner() {
			return jscolor.picker && jscolor.picker.owner === THIS;
		}


		function blurTarget() {
			if(valueElement === target) {
				THIS.importColor();
			}
			if(THIS.pickerOnfocus) {
				THIS.hidePicker();
			}
		}


		function blurValue() {
			if(valueElement !== target) {
				THIS.importColor();
			}
		}


		function setPad(e) {
			var mpos = jscolor.getRelMousePos(e);
			var x = mpos.x - THIS.pickerFace - THIS.pickerInset;
			var y = mpos.y - THIS.pickerFace - THIS.pickerInset;
			switch(modeID) {
				case 0: THIS.fromHSV(x*(6/(jscolor.images.pad[0]-1)), 1 - y/(jscolor.images.pad[1]-1), null, leaveSld); break;
				case 1: THIS.fromHSV(x*(6/(jscolor.images.pad[0]-1)), null, 1 - y/(jscolor.images.pad[1]-1), leaveSld); break;
			}
		}


		function setSld(e) {
			var mpos = jscolor.getRelMousePos(e);
			var y = mpos.y - THIS.pickerFace - THIS.pickerInset;
			switch(modeID) {
				case 0: THIS.fromHSV(null, null, 1 - y/(jscolor.images.sld[1]-1), leavePad); break;
				case 1: THIS.fromHSV(null, 1 - y/(jscolor.images.sld[1]-1), null, leavePad); break;
			}
		}


		function dispatchImmediateChange() {
			if (THIS.onImmediateChange) {
				var callback;
				if (typeof THIS.onImmediateChange === 'string') {
					callback = new Function (THIS.onImmediateChange);
				} else {
					callback = THIS.onImmediateChange;
				}
				callback.call(THIS);
			}
		}


		var THIS = this;
		var modeID = this.pickerMode.toLowerCase()==='hvs' ? 1 : 0;
		var abortBlur = false;
		var
			valueElement = jscolor.fetchElement(this.valueElement),
			styleElement = jscolor.fetchElement(this.styleElement);
		var
			holdPad = false,
			holdSld = false,
			touchOffset = {};
		var
			leaveValue = 1<<0,
			leaveStyle = 1<<1,
			leavePad = 1<<2,
			leaveSld = 1<<3;

		jscolor.isColorAttrSupported = false;
		var el = document.createElement('input');
		if(el.setAttribute) {
			el.setAttribute('type', 'color');
			if(el.type.toLowerCase() == 'color') {
				jscolor.isColorAttrSupported = true;
			}
		}

		// target
		jscolor.addEvent(target, 'focus', function() {
			if(THIS.pickerOnfocus) { THIS.showPicker(); }
		});
		jscolor.addEvent(target, 'blur', function() {
			if(!abortBlur) {
				window.setTimeout(function(){ abortBlur || blurTarget(); abortBlur=false; }, 0);
			} else {
				abortBlur = false;
			}
		});

		// valueElement
		if(valueElement) {
			var updateField = function() {
				THIS.fromString(valueElement.value, leaveValue);
				dispatchImmediateChange();
			};
			jscolor.addEvent(valueElement, 'keyup', updateField);
			jscolor.addEvent(valueElement, 'input', updateField);
			jscolor.addEvent(valueElement, 'blur', blurValue);
			valueElement.setAttribute('autocomplete', 'off');
		}

		// styleElement
		if(styleElement) {
			styleElement.jscStyle = {
				backgroundImage : styleElement.style.backgroundImage,
				backgroundColor : styleElement.style.backgroundColor,
				color : styleElement.style.color
			};
		}

		// require images
		switch(modeID) {
			case 0: jscolor.requireImage('hs.png'); break;
			case 1: jscolor.requireImage('hv.png'); break;
		}
		jscolor.requireImage('cross.gif');
		jscolor.requireImage('arrow.gif');

		this.importColor();
	}

};


jscolor.install();








/*!
 * Socket.IO v2.2.0
 * (c) 2014-2018 Guillermo Rauch
 * Released under the MIT License.
 */
!function(t,e){"object"==typeof exports&&"object"==typeof module?module.exports=e():"function"==typeof define&&define.amd?define([],e):"object"==typeof exports?exports.io=e():t.io=e()}(this,function(){return function(t){function e(r){if(n[r])return n[r].exports;var o=n[r]={exports:{},id:r,loaded:!1};return t[r].call(o.exports,o,o.exports,e),o.loaded=!0,o.exports}var n={};return e.m=t,e.c=n,e.p="",e(0)}([function(t,e,n){"use strict";function r(t,e){"object"===("undefined"==typeof t?"undefined":o(t))&&(e=t,t=void 0),e=e||{};var n,r=i(t),s=r.source,u=r.id,h=r.path,f=p[u]&&h in p[u].nsps,l=e.forceNew||e["force new connection"]||!1===e.multiplex||f;return l?(c("ignoring socket cache for %s",s),n=a(s,e)):(p[u]||(c("new io instance for %s",s),p[u]=a(s,e)),n=p[u]),r.query&&!e.query&&(e.query=r.query),n.socket(r.path,e)}var o="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(t){return typeof t}:function(t){return t&&"function"==typeof Symbol&&t.constructor===Symbol&&t!==Symbol.prototype?"symbol":typeof t},i=n(1),s=n(7),a=n(12),c=n(3)("socket.io-client");t.exports=e=r;var p=e.managers={};e.protocol=s.protocol,e.connect=r,e.Manager=n(12),e.Socket=n(36)},function(t,e,n){"use strict";function r(t,e){var n=t;e=e||"undefined"!=typeof location&&location,null==t&&(t=e.protocol+"//"+e.host),"string"==typeof t&&("/"===t.charAt(0)&&(t="/"===t.charAt(1)?e.protocol+t:e.host+t),/^(https?|wss?):\/\//.test(t)||(i("protocol-less url %s",t),t="undefined"!=typeof e?e.protocol+"//"+t:"https://"+t),i("parse %s",t),n=o(t)),n.port||(/^(http|ws)$/.test(n.protocol)?n.port="80":/^(http|ws)s$/.test(n.protocol)&&(n.port="443")),n.path=n.path||"/";var r=n.host.indexOf(":")!==-1,s=r?"["+n.host+"]":n.host;return n.id=n.protocol+"://"+s+":"+n.port,n.href=n.protocol+"://"+s+(e&&e.port===n.port?"":":"+n.port),n}var o=n(2),i=n(3)("socket.io-client:url");t.exports=r},function(t,e){var n=/^(?:(?![^:@]+:[^:@\/]*@)(http|https|ws|wss):\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?((?:[a-f0-9]{0,4}:){2,7}[a-f0-9]{0,4}|[^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/,r=["source","protocol","authority","userInfo","user","password","host","port","relative","path","directory","file","query","anchor"];t.exports=function(t){var e=t,o=t.indexOf("["),i=t.indexOf("]");o!=-1&&i!=-1&&(t=t.substring(0,o)+t.substring(o,i).replace(/:/g,";")+t.substring(i,t.length));for(var s=n.exec(t||""),a={},c=14;c--;)a[r[c]]=s[c]||"";return o!=-1&&i!=-1&&(a.source=e,a.host=a.host.substring(1,a.host.length-1).replace(/;/g,":"),a.authority=a.authority.replace("[","").replace("]","").replace(/;/g,":"),a.ipv6uri=!0),a}},function(t,e,n){(function(r){function o(){return!("undefined"==typeof window||!window.process||"renderer"!==window.process.type)||("undefined"==typeof navigator||!navigator.userAgent||!navigator.userAgent.toLowerCase().match(/(edge|trident)\/(\d+)/))&&("undefined"!=typeof document&&document.documentElement&&document.documentElement.style&&document.documentElement.style.WebkitAppearance||"undefined"!=typeof window&&window.console&&(window.console.firebug||window.console.exception&&window.console.table)||"undefined"!=typeof navigator&&navigator.userAgent&&navigator.userAgent.toLowerCase().match(/firefox\/(\d+)/)&&parseInt(RegExp.$1,10)>=31||"undefined"!=typeof navigator&&navigator.userAgent&&navigator.userAgent.toLowerCase().match(/applewebkit\/(\d+)/))}function i(t){var n=this.useColors;if(t[0]=(n?"%c":"")+this.namespace+(n?" %c":" ")+t[0]+(n?"%c ":" ")+"+"+e.humanize(this.diff),n){var r="color: "+this.color;t.splice(1,0,r,"color: inherit");var o=0,i=0;t[0].replace(/%[a-zA-Z%]/g,function(t){"%%"!==t&&(o++,"%c"===t&&(i=o))}),t.splice(i,0,r)}}function s(){return"object"==typeof console&&console.log&&Function.prototype.apply.call(console.log,console,arguments)}function a(t){try{null==t?e.storage.removeItem("debug"):e.storage.debug=t}catch(n){}}function c(){var t;try{t=e.storage.debug}catch(n){}return!t&&"undefined"!=typeof r&&"env"in r&&(t=r.env.DEBUG),t}function p(){try{return window.localStorage}catch(t){}}e=t.exports=n(5),e.log=s,e.formatArgs=i,e.save=a,e.load=c,e.useColors=o,e.storage="undefined"!=typeof chrome&&"undefined"!=typeof chrome.storage?chrome.storage.local:p(),e.colors=["#0000CC","#0000FF","#0033CC","#0033FF","#0066CC","#0066FF","#0099CC","#0099FF","#00CC00","#00CC33","#00CC66","#00CC99","#00CCCC","#00CCFF","#3300CC","#3300FF","#3333CC","#3333FF","#3366CC","#3366FF","#3399CC","#3399FF","#33CC00","#33CC33","#33CC66","#33CC99","#33CCCC","#33CCFF","#6600CC","#6600FF","#6633CC","#6633FF","#66CC00","#66CC33","#9900CC","#9900FF","#9933CC","#9933FF","#99CC00","#99CC33","#CC0000","#CC0033","#CC0066","#CC0099","#CC00CC","#CC00FF","#CC3300","#CC3333","#CC3366","#CC3399","#CC33CC","#CC33FF","#CC6600","#CC6633","#CC9900","#CC9933","#CCCC00","#CCCC33","#FF0000","#FF0033","#FF0066","#FF0099","#FF00CC","#FF00FF","#FF3300","#FF3333","#FF3366","#FF3399","#FF33CC","#FF33FF","#FF6600","#FF6633","#FF9900","#FF9933","#FFCC00","#FFCC33"],e.formatters.j=function(t){try{return JSON.stringify(t)}catch(e){return"[UnexpectedJSONParseError]: "+e.message}},e.enable(c())}).call(e,n(4))},function(t,e){function n(){throw new Error("setTimeout has not been defined")}function r(){throw new Error("clearTimeout has not been defined")}function o(t){if(u===setTimeout)return setTimeout(t,0);if((u===n||!u)&&setTimeout)return u=setTimeout,setTimeout(t,0);try{return u(t,0)}catch(e){try{return u.call(null,t,0)}catch(e){return u.call(this,t,0)}}}function i(t){if(h===clearTimeout)return clearTimeout(t);if((h===r||!h)&&clearTimeout)return h=clearTimeout,clearTimeout(t);try{return h(t)}catch(e){try{return h.call(null,t)}catch(e){return h.call(this,t)}}}function s(){y&&l&&(y=!1,l.length?d=l.concat(d):m=-1,d.length&&a())}function a(){if(!y){var t=o(s);y=!0;for(var e=d.length;e;){for(l=d,d=[];++m<e;)l&&l[m].run();m=-1,e=d.length}l=null,y=!1,i(t)}}function c(t,e){this.fun=t,this.array=e}function p(){}var u,h,f=t.exports={};!function(){try{u="function"==typeof setTimeout?setTimeout:n}catch(t){u=n}try{h="function"==typeof clearTimeout?clearTimeout:r}catch(t){h=r}}();var l,d=[],y=!1,m=-1;f.nextTick=function(t){var e=new Array(arguments.length-1);if(arguments.length>1)for(var n=1;n<arguments.length;n++)e[n-1]=arguments[n];d.push(new c(t,e)),1!==d.length||y||o(a)},c.prototype.run=function(){this.fun.apply(null,this.array)},f.title="browser",f.browser=!0,f.env={},f.argv=[],f.version="",f.versions={},f.on=p,f.addListener=p,f.once=p,f.off=p,f.removeListener=p,f.removeAllListeners=p,f.emit=p,f.prependListener=p,f.prependOnceListener=p,f.listeners=function(t){return[]},f.binding=function(t){throw new Error("process.binding is not supported")},f.cwd=function(){return"/"},f.chdir=function(t){throw new Error("process.chdir is not supported")},f.umask=function(){return 0}},function(t,e,n){function r(t){var n,r=0;for(n in t)r=(r<<5)-r+t.charCodeAt(n),r|=0;return e.colors[Math.abs(r)%e.colors.length]}function o(t){function n(){if(n.enabled){var t=n,r=+new Date,i=r-(o||r);t.diff=i,t.prev=o,t.curr=r,o=r;for(var s=new Array(arguments.length),a=0;a<s.length;a++)s[a]=arguments[a];s[0]=e.coerce(s[0]),"string"!=typeof s[0]&&s.unshift("%O");var c=0;s[0]=s[0].replace(/%([a-zA-Z%])/g,function(n,r){if("%%"===n)return n;c++;var o=e.formatters[r];if("function"==typeof o){var i=s[c];n=o.call(t,i),s.splice(c,1),c--}return n}),e.formatArgs.call(t,s);var p=n.log||e.log||console.log.bind(console);p.apply(t,s)}}var o;return n.namespace=t,n.enabled=e.enabled(t),n.useColors=e.useColors(),n.color=r(t),n.destroy=i,"function"==typeof e.init&&e.init(n),e.instances.push(n),n}function i(){var t=e.instances.indexOf(this);return t!==-1&&(e.instances.splice(t,1),!0)}function s(t){e.save(t),e.names=[],e.skips=[];var n,r=("string"==typeof t?t:"").split(/[\s,]+/),o=r.length;for(n=0;n<o;n++)r[n]&&(t=r[n].replace(/\*/g,".*?"),"-"===t[0]?e.skips.push(new RegExp("^"+t.substr(1)+"$")):e.names.push(new RegExp("^"+t+"$")));for(n=0;n<e.instances.length;n++){var i=e.instances[n];i.enabled=e.enabled(i.namespace)}}function a(){e.enable("")}function c(t){if("*"===t[t.length-1])return!0;var n,r;for(n=0,r=e.skips.length;n<r;n++)if(e.skips[n].test(t))return!1;for(n=0,r=e.names.length;n<r;n++)if(e.names[n].test(t))return!0;return!1}function p(t){return t instanceof Error?t.stack||t.message:t}e=t.exports=o.debug=o["default"]=o,e.coerce=p,e.disable=a,e.enable=s,e.enabled=c,e.humanize=n(6),e.instances=[],e.names=[],e.skips=[],e.formatters={}},function(t,e){function n(t){if(t=String(t),!(t.length>100)){var e=/^((?:\d+)?\.?\d+) *(milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|years?|yrs?|y)?$/i.exec(t);if(e){var n=parseFloat(e[1]),r=(e[2]||"ms").toLowerCase();switch(r){case"years":case"year":case"yrs":case"yr":case"y":return n*u;case"days":case"day":case"d":return n*p;case"hours":case"hour":case"hrs":case"hr":case"h":return n*c;case"minutes":case"minute":case"mins":case"min":case"m":return n*a;case"seconds":case"second":case"secs":case"sec":case"s":return n*s;case"milliseconds":case"millisecond":case"msecs":case"msec":case"ms":return n;default:return}}}}function r(t){return t>=p?Math.round(t/p)+"d":t>=c?Math.round(t/c)+"h":t>=a?Math.round(t/a)+"m":t>=s?Math.round(t/s)+"s":t+"ms"}function o(t){return i(t,p,"day")||i(t,c,"hour")||i(t,a,"minute")||i(t,s,"second")||t+" ms"}function i(t,e,n){if(!(t<e))return t<1.5*e?Math.floor(t/e)+" "+n:Math.ceil(t/e)+" "+n+"s"}var s=1e3,a=60*s,c=60*a,p=24*c,u=365.25*p;t.exports=function(t,e){e=e||{};var i=typeof t;if("string"===i&&t.length>0)return n(t);if("number"===i&&isNaN(t)===!1)return e["long"]?o(t):r(t);throw new Error("val is not a non-empty string or a valid number. val="+JSON.stringify(t))}},function(t,e,n){function r(){}function o(t){var n=""+t.type;if(e.BINARY_EVENT!==t.type&&e.BINARY_ACK!==t.type||(n+=t.attachments+"-"),t.nsp&&"/"!==t.nsp&&(n+=t.nsp+","),null!=t.id&&(n+=t.id),null!=t.data){var r=i(t.data);if(r===!1)return g;n+=r}return f("encoded %j as %s",t,n),n}function i(t){try{return JSON.stringify(t)}catch(e){return!1}}function s(t,e){function n(t){var n=d.deconstructPacket(t),r=o(n.packet),i=n.buffers;i.unshift(r),e(i)}d.removeBlobs(t,n)}function a(){this.reconstructor=null}function c(t){var n=0,r={type:Number(t.charAt(0))};if(null==e.types[r.type])return h("unknown packet type "+r.type);if(e.BINARY_EVENT===r.type||e.BINARY_ACK===r.type){for(var o="";"-"!==t.charAt(++n)&&(o+=t.charAt(n),n!=t.length););if(o!=Number(o)||"-"!==t.charAt(n))throw new Error("Illegal attachments");r.attachments=Number(o)}if("/"===t.charAt(n+1))for(r.nsp="";++n;){var i=t.charAt(n);if(","===i)break;if(r.nsp+=i,n===t.length)break}else r.nsp="/";var s=t.charAt(n+1);if(""!==s&&Number(s)==s){for(r.id="";++n;){var i=t.charAt(n);if(null==i||Number(i)!=i){--n;break}if(r.id+=t.charAt(n),n===t.length)break}r.id=Number(r.id)}if(t.charAt(++n)){var a=p(t.substr(n)),c=a!==!1&&(r.type===e.ERROR||y(a));if(!c)return h("invalid payload");r.data=a}return f("decoded %s as %j",t,r),r}function p(t){try{return JSON.parse(t)}catch(e){return!1}}function u(t){this.reconPack=t,this.buffers=[]}function h(t){return{type:e.ERROR,data:"parser error: "+t}}var f=n(3)("socket.io-parser"),l=n(8),d=n(9),y=n(10),m=n(11);e.protocol=4,e.types=["CONNECT","DISCONNECT","EVENT","ACK","ERROR","BINARY_EVENT","BINARY_ACK"],e.CONNECT=0,e.DISCONNECT=1,e.EVENT=2,e.ACK=3,e.ERROR=4,e.BINARY_EVENT=5,e.BINARY_ACK=6,e.Encoder=r,e.Decoder=a;var g=e.ERROR+'"encode error"';r.prototype.encode=function(t,n){if(f("encoding packet %j",t),e.BINARY_EVENT===t.type||e.BINARY_ACK===t.type)s(t,n);else{var r=o(t);n([r])}},l(a.prototype),a.prototype.add=function(t){var n;if("string"==typeof t)n=c(t),e.BINARY_EVENT===n.type||e.BINARY_ACK===n.type?(this.reconstructor=new u(n),0===this.reconstructor.reconPack.attachments&&this.emit("decoded",n)):this.emit("decoded",n);else{if(!m(t)&&!t.base64)throw new Error("Unknown type: "+t);if(!this.reconstructor)throw new Error("got binary data when not reconstructing a packet");n=this.reconstructor.takeBinaryData(t),n&&(this.reconstructor=null,this.emit("decoded",n))}},a.prototype.destroy=function(){this.reconstructor&&this.reconstructor.finishedReconstruction()},u.prototype.takeBinaryData=function(t){if(this.buffers.push(t),this.buffers.length===this.reconPack.attachments){var e=d.reconstructPacket(this.reconPack,this.buffers);return this.finishedReconstruction(),e}return null},u.prototype.finishedReconstruction=function(){this.reconPack=null,this.buffers=[]}},function(t,e,n){function r(t){if(t)return o(t)}function o(t){for(var e in r.prototype)t[e]=r.prototype[e];return t}t.exports=r,r.prototype.on=r.prototype.addEventListener=function(t,e){return this._callbacks=this._callbacks||{},(this._callbacks["$"+t]=this._callbacks["$"+t]||[]).push(e),this},r.prototype.once=function(t,e){function n(){this.off(t,n),e.apply(this,arguments)}return n.fn=e,this.on(t,n),this},r.prototype.off=r.prototype.removeListener=r.prototype.removeAllListeners=r.prototype.removeEventListener=function(t,e){if(this._callbacks=this._callbacks||{},0==arguments.length)return this._callbacks={},this;var n=this._callbacks["$"+t];if(!n)return this;if(1==arguments.length)return delete this._callbacks["$"+t],this;for(var r,o=0;o<n.length;o++)if(r=n[o],r===e||r.fn===e){n.splice(o,1);break}return this},r.prototype.emit=function(t){this._callbacks=this._callbacks||{};var e=[].slice.call(arguments,1),n=this._callbacks["$"+t];if(n){n=n.slice(0);for(var r=0,o=n.length;r<o;++r)n[r].apply(this,e)}return this},r.prototype.listeners=function(t){return this._callbacks=this._callbacks||{},this._callbacks["$"+t]||[]},r.prototype.hasListeners=function(t){return!!this.listeners(t).length}},function(t,e,n){function r(t,e){if(!t)return t;if(s(t)){var n={_placeholder:!0,num:e.length};return e.push(t),n}if(i(t)){for(var o=new Array(t.length),a=0;a<t.length;a++)o[a]=r(t[a],e);return o}if("object"==typeof t&&!(t instanceof Date)){var o={};for(var c in t)o[c]=r(t[c],e);return o}return t}function o(t,e){if(!t)return t;if(t&&t._placeholder)return e[t.num];if(i(t))for(var n=0;n<t.length;n++)t[n]=o(t[n],e);else if("object"==typeof t)for(var r in t)t[r]=o(t[r],e);return t}var i=n(10),s=n(11),a=Object.prototype.toString,c="function"==typeof Blob||"undefined"!=typeof Blob&&"[object BlobConstructor]"===a.call(Blob),p="function"==typeof File||"undefined"!=typeof File&&"[object FileConstructor]"===a.call(File);e.deconstructPacket=function(t){var e=[],n=t.data,o=t;return o.data=r(n,e),o.attachments=e.length,{packet:o,buffers:e}},e.reconstructPacket=function(t,e){return t.data=o(t.data,e),t.attachments=void 0,t},e.removeBlobs=function(t,e){function n(t,a,u){if(!t)return t;if(c&&t instanceof Blob||p&&t instanceof File){r++;var h=new FileReader;h.onload=function(){u?u[a]=this.result:o=this.result,--r||e(o)},h.readAsArrayBuffer(t)}else if(i(t))for(var f=0;f<t.length;f++)n(t[f],f,t);else if("object"==typeof t&&!s(t))for(var l in t)n(t[l],l,t)}var r=0,o=t;n(o),r||e(o)}},function(t,e){var n={}.toString;t.exports=Array.isArray||function(t){return"[object Array]"==n.call(t)}},function(t,e){function n(t){return r&&Buffer.isBuffer(t)||o&&(t instanceof ArrayBuffer||i(t))}t.exports=n;var r="function"==typeof Buffer&&"function"==typeof Buffer.isBuffer,o="function"==typeof ArrayBuffer,i=function(t){return"function"==typeof ArrayBuffer.isView?ArrayBuffer.isView(t):t.buffer instanceof ArrayBuffer}},function(t,e,n){"use strict";function r(t,e){if(!(this instanceof r))return new r(t,e);t&&"object"===("undefined"==typeof t?"undefined":o(t))&&(e=t,t=void 0),e=e||{},e.path=e.path||"/socket.io",this.nsps={},this.subs=[],this.opts=e,this.reconnection(e.reconnection!==!1),this.reconnectionAttempts(e.reconnectionAttempts||1/0),this.reconnectionDelay(e.reconnectionDelay||1e3),this.reconnectionDelayMax(e.reconnectionDelayMax||5e3),this.randomizationFactor(e.randomizationFactor||.5),this.backoff=new l({min:this.reconnectionDelay(),max:this.reconnectionDelayMax(),jitter:this.randomizationFactor()}),this.timeout(null==e.timeout?2e4:e.timeout),this.readyState="closed",this.uri=t,this.connecting=[],this.lastPing=null,this.encoding=!1,this.packetBuffer=[];var n=e.parser||c;this.encoder=new n.Encoder,this.decoder=new n.Decoder,this.autoConnect=e.autoConnect!==!1,this.autoConnect&&this.open()}var o="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(t){return typeof t}:function(t){return t&&"function"==typeof Symbol&&t.constructor===Symbol&&t!==Symbol.prototype?"symbol":typeof t},i=n(13),s=n(36),a=n(8),c=n(7),p=n(38),u=n(39),h=n(3)("socket.io-client:manager"),f=n(35),l=n(40),d=Object.prototype.hasOwnProperty;t.exports=r,r.prototype.emitAll=function(){this.emit.apply(this,arguments);for(var t in this.nsps)d.call(this.nsps,t)&&this.nsps[t].emit.apply(this.nsps[t],arguments)},r.prototype.updateSocketIds=function(){for(var t in this.nsps)d.call(this.nsps,t)&&(this.nsps[t].id=this.generateId(t))},r.prototype.generateId=function(t){return("/"===t?"":t+"#")+this.engine.id},a(r.prototype),r.prototype.reconnection=function(t){return arguments.length?(this._reconnection=!!t,this):this._reconnection},r.prototype.reconnectionAttempts=function(t){return arguments.length?(this._reconnectionAttempts=t,this):this._reconnectionAttempts},r.prototype.reconnectionDelay=function(t){return arguments.length?(this._reconnectionDelay=t,this.backoff&&this.backoff.setMin(t),this):this._reconnectionDelay},r.prototype.randomizationFactor=function(t){return arguments.length?(this._randomizationFactor=t,this.backoff&&this.backoff.setJitter(t),this):this._randomizationFactor},r.prototype.reconnectionDelayMax=function(t){return arguments.length?(this._reconnectionDelayMax=t,this.backoff&&this.backoff.setMax(t),this):this._reconnectionDelayMax},r.prototype.timeout=function(t){return arguments.length?(this._timeout=t,this):this._timeout},r.prototype.maybeReconnectOnOpen=function(){!this.reconnecting&&this._reconnection&&0===this.backoff.attempts&&this.reconnect()},r.prototype.open=r.prototype.connect=function(t,e){if(h("readyState %s",this.readyState),~this.readyState.indexOf("open"))return this;h("opening %s",this.uri),this.engine=i(this.uri,this.opts);var n=this.engine,r=this;this.readyState="opening",this.skipReconnect=!1;var o=p(n,"open",function(){r.onopen(),t&&t()}),s=p(n,"error",function(e){if(h("connect_error"),r.cleanup(),r.readyState="closed",r.emitAll("connect_error",e),t){var n=new Error("Connection error");n.data=e,t(n)}else r.maybeReconnectOnOpen()});if(!1!==this._timeout){var a=this._timeout;h("connect attempt will timeout after %d",a);var c=setTimeout(function(){h("connect attempt timed out after %d",a),o.destroy(),n.close(),n.emit("error","timeout"),r.emitAll("connect_timeout",a)},a);this.subs.push({destroy:function(){clearTimeout(c)}})}return this.subs.push(o),this.subs.push(s),this},r.prototype.onopen=function(){h("open"),this.cleanup(),this.readyState="open",this.emit("open");var t=this.engine;this.subs.push(p(t,"data",u(this,"ondata"))),this.subs.push(p(t,"ping",u(this,"onping"))),this.subs.push(p(t,"pong",u(this,"onpong"))),this.subs.push(p(t,"error",u(this,"onerror"))),this.subs.push(p(t,"close",u(this,"onclose"))),this.subs.push(p(this.decoder,"decoded",u(this,"ondecoded")))},r.prototype.onping=function(){this.lastPing=new Date,this.emitAll("ping")},r.prototype.onpong=function(){this.emitAll("pong",new Date-this.lastPing)},r.prototype.ondata=function(t){this.decoder.add(t)},r.prototype.ondecoded=function(t){this.emit("packet",t)},r.prototype.onerror=function(t){h("error",t),this.emitAll("error",t)},r.prototype.socket=function(t,e){function n(){~f(o.connecting,r)||o.connecting.push(r)}var r=this.nsps[t];if(!r){r=new s(this,t,e),this.nsps[t]=r;var o=this;r.on("connecting",n),r.on("connect",function(){r.id=o.generateId(t)}),this.autoConnect&&n()}return r},r.prototype.destroy=function(t){var e=f(this.connecting,t);~e&&this.connecting.splice(e,1),this.connecting.length||this.close()},r.prototype.packet=function(t){h("writing packet %j",t);var e=this;t.query&&0===t.type&&(t.nsp+="?"+t.query),e.encoding?e.packetBuffer.push(t):(e.encoding=!0,this.encoder.encode(t,function(n){for(var r=0;r<n.length;r++)e.engine.write(n[r],t.options);e.encoding=!1,e.processPacketQueue()}))},r.prototype.processPacketQueue=function(){if(this.packetBuffer.length>0&&!this.encoding){var t=this.packetBuffer.shift();this.packet(t)}},r.prototype.cleanup=function(){h("cleanup");for(var t=this.subs.length,e=0;e<t;e++){var n=this.subs.shift();n.destroy()}this.packetBuffer=[],this.encoding=!1,this.lastPing=null,this.decoder.destroy()},r.prototype.close=r.prototype.disconnect=function(){h("disconnect"),this.skipReconnect=!0,this.reconnecting=!1,"opening"===this.readyState&&this.cleanup(),this.backoff.reset(),this.readyState="closed",this.engine&&this.engine.close()},r.prototype.onclose=function(t){h("onclose"),this.cleanup(),this.backoff.reset(),this.readyState="closed",this.emit("close",t),this._reconnection&&!this.skipReconnect&&this.reconnect()},r.prototype.reconnect=function(){if(this.reconnecting||this.skipReconnect)return this;var t=this;if(this.backoff.attempts>=this._reconnectionAttempts)h("reconnect failed"),this.backoff.reset(),this.emitAll("reconnect_failed"),this.reconnecting=!1;else{var e=this.backoff.duration();h("will wait %dms before reconnect attempt",e),this.reconnecting=!0;var n=setTimeout(function(){t.skipReconnect||(h("attempting reconnect"),t.emitAll("reconnect_attempt",t.backoff.attempts),t.emitAll("reconnecting",t.backoff.attempts),t.skipReconnect||t.open(function(e){e?(h("reconnect attempt error"),t.reconnecting=!1,t.reconnect(),t.emitAll("reconnect_error",e.data)):(h("reconnect success"),t.onreconnect())}))},e);this.subs.push({destroy:function(){clearTimeout(n)}})}},r.prototype.onreconnect=function(){var t=this.backoff.attempts;this.reconnecting=!1,this.backoff.reset(),this.updateSocketIds(),this.emitAll("reconnect",t)}},function(t,e,n){t.exports=n(14),t.exports.parser=n(21)},function(t,e,n){function r(t,e){return this instanceof r?(e=e||{},t&&"object"==typeof t&&(e=t,t=null),t?(t=u(t),e.hostname=t.host,e.secure="https"===t.protocol||"wss"===t.protocol,e.port=t.port,t.query&&(e.query=t.query)):e.host&&(e.hostname=u(e.host).host),this.secure=null!=e.secure?e.secure:"undefined"!=typeof location&&"https:"===location.protocol,e.hostname&&!e.port&&(e.port=this.secure?"443":"80"),this.agent=e.agent||!1,this.hostname=e.hostname||("undefined"!=typeof location?location.hostname:"localhost"),this.port=e.port||("undefined"!=typeof location&&location.port?location.port:this.secure?443:80),this.query=e.query||{},"string"==typeof this.query&&(this.query=h.decode(this.query)),this.upgrade=!1!==e.upgrade,this.path=(e.path||"/engine.io").replace(/\/$/,"")+"/",this.forceJSONP=!!e.forceJSONP,this.jsonp=!1!==e.jsonp,this.forceBase64=!!e.forceBase64,this.enablesXDR=!!e.enablesXDR,this.timestampParam=e.timestampParam||"t",this.timestampRequests=e.timestampRequests,this.transports=e.transports||["polling","websocket"],this.transportOptions=e.transportOptions||{},this.readyState="",this.writeBuffer=[],this.prevBufferLen=0,this.policyPort=e.policyPort||843,this.rememberUpgrade=e.rememberUpgrade||!1,this.binaryType=null,this.onlyBinaryUpgrades=e.onlyBinaryUpgrades,this.perMessageDeflate=!1!==e.perMessageDeflate&&(e.perMessageDeflate||{}),!0===this.perMessageDeflate&&(this.perMessageDeflate={}),this.perMessageDeflate&&null==this.perMessageDeflate.threshold&&(this.perMessageDeflate.threshold=1024),this.pfx=e.pfx||null,this.key=e.key||null,this.passphrase=e.passphrase||null,this.cert=e.cert||null,this.ca=e.ca||null,this.ciphers=e.ciphers||null,this.rejectUnauthorized=void 0===e.rejectUnauthorized||e.rejectUnauthorized,this.forceNode=!!e.forceNode,this.isReactNative="undefined"!=typeof navigator&&"string"==typeof navigator.product&&"reactnative"===navigator.product.toLowerCase(),("undefined"==typeof self||this.isReactNative)&&(e.extraHeaders&&Object.keys(e.extraHeaders).length>0&&(this.extraHeaders=e.extraHeaders),e.localAddress&&(this.localAddress=e.localAddress)),this.id=null,this.upgrades=null,this.pingInterval=null,this.pingTimeout=null,this.pingIntervalTimer=null,this.pingTimeoutTimer=null,void this.open()):new r(t,e)}function o(t){var e={};for(var n in t)t.hasOwnProperty(n)&&(e[n]=t[n]);return e}var i=n(15),s=n(8),a=n(3)("engine.io-client:socket"),c=n(35),p=n(21),u=n(2),h=n(29);t.exports=r,r.priorWebsocketSuccess=!1,s(r.prototype),r.protocol=p.protocol,r.Socket=r,r.Transport=n(20),r.transports=n(15),r.parser=n(21),r.prototype.createTransport=function(t){a('creating transport "%s"',t);var e=o(this.query);e.EIO=p.protocol,e.transport=t;var n=this.transportOptions[t]||{};this.id&&(e.sid=this.id);var r=new i[t]({query:e,socket:this,agent:n.agent||this.agent,hostname:n.hostname||this.hostname,port:n.port||this.port,secure:n.secure||this.secure,path:n.path||this.path,forceJSONP:n.forceJSONP||this.forceJSONP,jsonp:n.jsonp||this.jsonp,forceBase64:n.forceBase64||this.forceBase64,enablesXDR:n.enablesXDR||this.enablesXDR,timestampRequests:n.timestampRequests||this.timestampRequests,timestampParam:n.timestampParam||this.timestampParam,policyPort:n.policyPort||this.policyPort,pfx:n.pfx||this.pfx,key:n.key||this.key,passphrase:n.passphrase||this.passphrase,cert:n.cert||this.cert,ca:n.ca||this.ca,ciphers:n.ciphers||this.ciphers,rejectUnauthorized:n.rejectUnauthorized||this.rejectUnauthorized,perMessageDeflate:n.perMessageDeflate||this.perMessageDeflate,extraHeaders:n.extraHeaders||this.extraHeaders,forceNode:n.forceNode||this.forceNode,localAddress:n.localAddress||this.localAddress,requestTimeout:n.requestTimeout||this.requestTimeout,protocols:n.protocols||void 0,isReactNative:this.isReactNative});return r},r.prototype.open=function(){var t;if(this.rememberUpgrade&&r.priorWebsocketSuccess&&this.transports.indexOf("websocket")!==-1)t="websocket";else{if(0===this.transports.length){var e=this;return void setTimeout(function(){e.emit("error","No transports available")},0)}t=this.transports[0]}this.readyState="opening";try{t=this.createTransport(t)}catch(n){return this.transports.shift(),void this.open()}t.open(),this.setTransport(t)},r.prototype.setTransport=function(t){a("setting transport %s",t.name);var e=this;this.transport&&(a("clearing existing transport %s",this.transport.name),this.transport.removeAllListeners()),this.transport=t,t.on("drain",function(){e.onDrain()}).on("packet",function(t){e.onPacket(t)}).on("error",function(t){e.onError(t)}).on("close",function(){e.onClose("transport close")})},r.prototype.probe=function(t){function e(){if(f.onlyBinaryUpgrades){var e=!this.supportsBinary&&f.transport.supportsBinary;h=h||e}h||(a('probe transport "%s" opened',t),u.send([{type:"ping",data:"probe"}]),u.once("packet",function(e){if(!h)if("pong"===e.type&&"probe"===e.data){if(a('probe transport "%s" pong',t),f.upgrading=!0,f.emit("upgrading",u),!u)return;r.priorWebsocketSuccess="websocket"===u.name,a('pausing current transport "%s"',f.transport.name),f.transport.pause(function(){h||"closed"!==f.readyState&&(a("changing transport and sending upgrade packet"),p(),f.setTransport(u),u.send([{type:"upgrade"}]),f.emit("upgrade",u),u=null,f.upgrading=!1,f.flush())})}else{a('probe transport "%s" failed',t);var n=new Error("probe error");n.transport=u.name,f.emit("upgradeError",n)}}))}function n(){h||(h=!0,p(),u.close(),u=null)}function o(e){var r=new Error("probe error: "+e);r.transport=u.name,n(),a('probe transport "%s" failed because of error: %s',t,e),f.emit("upgradeError",r)}function i(){o("transport closed")}function s(){o("socket closed")}function c(t){u&&t.name!==u.name&&(a('"%s" works - aborting "%s"',t.name,u.name),n())}function p(){u.removeListener("open",e),u.removeListener("error",o),u.removeListener("close",i),f.removeListener("close",s),f.removeListener("upgrading",c)}a('probing transport "%s"',t);var u=this.createTransport(t,{probe:1}),h=!1,f=this;r.priorWebsocketSuccess=!1,u.once("open",e),u.once("error",o),u.once("close",i),this.once("close",s),this.once("upgrading",c),u.open()},r.prototype.onOpen=function(){if(a("socket open"),this.readyState="open",r.priorWebsocketSuccess="websocket"===this.transport.name,this.emit("open"),this.flush(),"open"===this.readyState&&this.upgrade&&this.transport.pause){a("starting upgrade probes");for(var t=0,e=this.upgrades.length;t<e;t++)this.probe(this.upgrades[t])}},r.prototype.onPacket=function(t){if("opening"===this.readyState||"open"===this.readyState||"closing"===this.readyState)switch(a('socket receive: type "%s", data "%s"',t.type,t.data),this.emit("packet",t),this.emit("heartbeat"),t.type){case"open":this.onHandshake(JSON.parse(t.data));break;case"pong":this.setPing(),this.emit("pong");break;case"error":var e=new Error("server error");e.code=t.data,this.onError(e);break;case"message":this.emit("data",t.data),this.emit("message",t.data)}else a('packet received with socket readyState "%s"',this.readyState)},r.prototype.onHandshake=function(t){this.emit("handshake",t),this.id=t.sid,this.transport.query.sid=t.sid,this.upgrades=this.filterUpgrades(t.upgrades),this.pingInterval=t.pingInterval,this.pingTimeout=t.pingTimeout,this.onOpen(),"closed"!==this.readyState&&(this.setPing(),this.removeListener("heartbeat",this.onHeartbeat),this.on("heartbeat",this.onHeartbeat))},r.prototype.onHeartbeat=function(t){clearTimeout(this.pingTimeoutTimer);var e=this;e.pingTimeoutTimer=setTimeout(function(){"closed"!==e.readyState&&e.onClose("ping timeout")},t||e.pingInterval+e.pingTimeout)},r.prototype.setPing=function(){var t=this;clearTimeout(t.pingIntervalTimer),t.pingIntervalTimer=setTimeout(function(){a("writing ping packet - expecting pong within %sms",t.pingTimeout),t.ping(),t.onHeartbeat(t.pingTimeout)},t.pingInterval)},r.prototype.ping=function(){var t=this;this.sendPacket("ping",function(){t.emit("ping")})},r.prototype.onDrain=function(){this.writeBuffer.splice(0,this.prevBufferLen),this.prevBufferLen=0,0===this.writeBuffer.length?this.emit("drain"):this.flush()},r.prototype.flush=function(){"closed"!==this.readyState&&this.transport.writable&&!this.upgrading&&this.writeBuffer.length&&(a("flushing %d packets in socket",this.writeBuffer.length),this.transport.send(this.writeBuffer),this.prevBufferLen=this.writeBuffer.length,this.emit("flush"))},r.prototype.write=r.prototype.send=function(t,e,n){return this.sendPacket("message",t,e,n),this},r.prototype.sendPacket=function(t,e,n,r){if("function"==typeof e&&(r=e,e=void 0),"function"==typeof n&&(r=n,n=null),"closing"!==this.readyState&&"closed"!==this.readyState){n=n||{},n.compress=!1!==n.compress;var o={type:t,data:e,options:n};this.emit("packetCreate",o),this.writeBuffer.push(o),r&&this.once("flush",r),this.flush()}},r.prototype.close=function(){function t(){r.onClose("forced close"),a("socket closing - telling transport to close"),r.transport.close()}function e(){r.removeListener("upgrade",e),r.removeListener("upgradeError",e),t()}function n(){r.once("upgrade",e),r.once("upgradeError",e)}if("opening"===this.readyState||"open"===this.readyState){this.readyState="closing";var r=this;this.writeBuffer.length?this.once("drain",function(){this.upgrading?n():t()}):this.upgrading?n():t()}return this},r.prototype.onError=function(t){a("socket error %j",t),r.priorWebsocketSuccess=!1,this.emit("error",t),this.onClose("transport error",t)},r.prototype.onClose=function(t,e){if("opening"===this.readyState||"open"===this.readyState||"closing"===this.readyState){a('socket close with reason: "%s"',t);var n=this;clearTimeout(this.pingIntervalTimer),clearTimeout(this.pingTimeoutTimer),this.transport.removeAllListeners("close"),this.transport.close(),this.transport.removeAllListeners(),this.readyState="closed",this.id=null,this.emit("close",t,e),n.writeBuffer=[],n.prevBufferLen=0}},r.prototype.filterUpgrades=function(t){for(var e=[],n=0,r=t.length;n<r;n++)~c(this.transports,t[n])&&e.push(t[n]);return e}},function(t,e,n){function r(t){var e,n=!1,r=!1,a=!1!==t.jsonp;
if("undefined"!=typeof location){var c="https:"===location.protocol,p=location.port;p||(p=c?443:80),n=t.hostname!==location.hostname||p!==t.port,r=t.secure!==c}if(t.xdomain=n,t.xscheme=r,e=new o(t),"open"in e&&!t.forceJSONP)return new i(t);if(!a)throw new Error("JSONP disabled");return new s(t)}var o=n(16),i=n(18),s=n(32),a=n(33);e.polling=r,e.websocket=a},function(t,e,n){var r=n(17);t.exports=function(t){var e=t.xdomain,n=t.xscheme,o=t.enablesXDR;try{if("undefined"!=typeof XMLHttpRequest&&(!e||r))return new XMLHttpRequest}catch(i){}try{if("undefined"!=typeof XDomainRequest&&!n&&o)return new XDomainRequest}catch(i){}if(!e)try{return new(self[["Active"].concat("Object").join("X")])("Microsoft.XMLHTTP")}catch(i){}}},function(t,e){try{t.exports="undefined"!=typeof XMLHttpRequest&&"withCredentials"in new XMLHttpRequest}catch(n){t.exports=!1}},function(t,e,n){function r(){}function o(t){if(c.call(this,t),this.requestTimeout=t.requestTimeout,this.extraHeaders=t.extraHeaders,"undefined"!=typeof location){var e="https:"===location.protocol,n=location.port;n||(n=e?443:80),this.xd="undefined"!=typeof location&&t.hostname!==location.hostname||n!==t.port,this.xs=t.secure!==e}}function i(t){this.method=t.method||"GET",this.uri=t.uri,this.xd=!!t.xd,this.xs=!!t.xs,this.async=!1!==t.async,this.data=void 0!==t.data?t.data:null,this.agent=t.agent,this.isBinary=t.isBinary,this.supportsBinary=t.supportsBinary,this.enablesXDR=t.enablesXDR,this.requestTimeout=t.requestTimeout,this.pfx=t.pfx,this.key=t.key,this.passphrase=t.passphrase,this.cert=t.cert,this.ca=t.ca,this.ciphers=t.ciphers,this.rejectUnauthorized=t.rejectUnauthorized,this.extraHeaders=t.extraHeaders,this.create()}function s(){for(var t in i.requests)i.requests.hasOwnProperty(t)&&i.requests[t].abort()}var a=n(16),c=n(19),p=n(8),u=n(30),h=n(3)("engine.io-client:polling-xhr");if(t.exports=o,t.exports.Request=i,u(o,c),o.prototype.supportsBinary=!0,o.prototype.request=function(t){return t=t||{},t.uri=this.uri(),t.xd=this.xd,t.xs=this.xs,t.agent=this.agent||!1,t.supportsBinary=this.supportsBinary,t.enablesXDR=this.enablesXDR,t.pfx=this.pfx,t.key=this.key,t.passphrase=this.passphrase,t.cert=this.cert,t.ca=this.ca,t.ciphers=this.ciphers,t.rejectUnauthorized=this.rejectUnauthorized,t.requestTimeout=this.requestTimeout,t.extraHeaders=this.extraHeaders,new i(t)},o.prototype.doWrite=function(t,e){var n="string"!=typeof t&&void 0!==t,r=this.request({method:"POST",data:t,isBinary:n}),o=this;r.on("success",e),r.on("error",function(t){o.onError("xhr post error",t)}),this.sendXhr=r},o.prototype.doPoll=function(){h("xhr poll");var t=this.request(),e=this;t.on("data",function(t){e.onData(t)}),t.on("error",function(t){e.onError("xhr poll error",t)}),this.pollXhr=t},p(i.prototype),i.prototype.create=function(){var t={agent:this.agent,xdomain:this.xd,xscheme:this.xs,enablesXDR:this.enablesXDR};t.pfx=this.pfx,t.key=this.key,t.passphrase=this.passphrase,t.cert=this.cert,t.ca=this.ca,t.ciphers=this.ciphers,t.rejectUnauthorized=this.rejectUnauthorized;var e=this.xhr=new a(t),n=this;try{h("xhr open %s: %s",this.method,this.uri),e.open(this.method,this.uri,this.async);try{if(this.extraHeaders){e.setDisableHeaderCheck&&e.setDisableHeaderCheck(!0);for(var r in this.extraHeaders)this.extraHeaders.hasOwnProperty(r)&&e.setRequestHeader(r,this.extraHeaders[r])}}catch(o){}if("POST"===this.method)try{this.isBinary?e.setRequestHeader("Content-type","application/octet-stream"):e.setRequestHeader("Content-type","text/plain;charset=UTF-8")}catch(o){}try{e.setRequestHeader("Accept","*/*")}catch(o){}"withCredentials"in e&&(e.withCredentials=!0),this.requestTimeout&&(e.timeout=this.requestTimeout),this.hasXDR()?(e.onload=function(){n.onLoad()},e.onerror=function(){n.onError(e.responseText)}):e.onreadystatechange=function(){if(2===e.readyState)try{var t=e.getResponseHeader("Content-Type");n.supportsBinary&&"application/octet-stream"===t&&(e.responseType="arraybuffer")}catch(r){}4===e.readyState&&(200===e.status||1223===e.status?n.onLoad():setTimeout(function(){n.onError(e.status)},0))},h("xhr data %s",this.data),e.send(this.data)}catch(o){return void setTimeout(function(){n.onError(o)},0)}"undefined"!=typeof document&&(this.index=i.requestsCount++,i.requests[this.index]=this)},i.prototype.onSuccess=function(){this.emit("success"),this.cleanup()},i.prototype.onData=function(t){this.emit("data",t),this.onSuccess()},i.prototype.onError=function(t){this.emit("error",t),this.cleanup(!0)},i.prototype.cleanup=function(t){if("undefined"!=typeof this.xhr&&null!==this.xhr){if(this.hasXDR()?this.xhr.onload=this.xhr.onerror=r:this.xhr.onreadystatechange=r,t)try{this.xhr.abort()}catch(e){}"undefined"!=typeof document&&delete i.requests[this.index],this.xhr=null}},i.prototype.onLoad=function(){var t;try{var e;try{e=this.xhr.getResponseHeader("Content-Type")}catch(n){}t="application/octet-stream"===e?this.xhr.response||this.xhr.responseText:this.xhr.responseText}catch(n){this.onError(n)}null!=t&&this.onData(t)},i.prototype.hasXDR=function(){return"undefined"!=typeof XDomainRequest&&!this.xs&&this.enablesXDR},i.prototype.abort=function(){this.cleanup()},i.requestsCount=0,i.requests={},"undefined"!=typeof document)if("function"==typeof attachEvent)attachEvent("onunload",s);else if("function"==typeof addEventListener){var f="onpagehide"in self?"pagehide":"unload";addEventListener(f,s,!1)}},function(t,e,n){function r(t){var e=t&&t.forceBase64;u&&!e||(this.supportsBinary=!1),o.call(this,t)}var o=n(20),i=n(29),s=n(21),a=n(30),c=n(31),p=n(3)("engine.io-client:polling");t.exports=r;var u=function(){var t=n(16),e=new t({xdomain:!1});return null!=e.responseType}();a(r,o),r.prototype.name="polling",r.prototype.doOpen=function(){this.poll()},r.prototype.pause=function(t){function e(){p("paused"),n.readyState="paused",t()}var n=this;if(this.readyState="pausing",this.polling||!this.writable){var r=0;this.polling&&(p("we are currently polling - waiting to pause"),r++,this.once("pollComplete",function(){p("pre-pause polling complete"),--r||e()})),this.writable||(p("we are currently writing - waiting to pause"),r++,this.once("drain",function(){p("pre-pause writing complete"),--r||e()}))}else e()},r.prototype.poll=function(){p("polling"),this.polling=!0,this.doPoll(),this.emit("poll")},r.prototype.onData=function(t){var e=this;p("polling got data %s",t);var n=function(t,n,r){return"opening"===e.readyState&&e.onOpen(),"close"===t.type?(e.onClose(),!1):void e.onPacket(t)};s.decodePayload(t,this.socket.binaryType,n),"closed"!==this.readyState&&(this.polling=!1,this.emit("pollComplete"),"open"===this.readyState?this.poll():p('ignoring poll - transport state "%s"',this.readyState))},r.prototype.doClose=function(){function t(){p("writing close packet"),e.write([{type:"close"}])}var e=this;"open"===this.readyState?(p("transport open - closing"),t()):(p("transport not open - deferring close"),this.once("open",t))},r.prototype.write=function(t){var e=this;this.writable=!1;var n=function(){e.writable=!0,e.emit("drain")};s.encodePayload(t,this.supportsBinary,function(t){e.doWrite(t,n)})},r.prototype.uri=function(){var t=this.query||{},e=this.secure?"https":"http",n="";!1!==this.timestampRequests&&(t[this.timestampParam]=c()),this.supportsBinary||t.sid||(t.b64=1),t=i.encode(t),this.port&&("https"===e&&443!==Number(this.port)||"http"===e&&80!==Number(this.port))&&(n=":"+this.port),t.length&&(t="?"+t);var r=this.hostname.indexOf(":")!==-1;return e+"://"+(r?"["+this.hostname+"]":this.hostname)+n+this.path+t}},function(t,e,n){function r(t){this.path=t.path,this.hostname=t.hostname,this.port=t.port,this.secure=t.secure,this.query=t.query,this.timestampParam=t.timestampParam,this.timestampRequests=t.timestampRequests,this.readyState="",this.agent=t.agent||!1,this.socket=t.socket,this.enablesXDR=t.enablesXDR,this.pfx=t.pfx,this.key=t.key,this.passphrase=t.passphrase,this.cert=t.cert,this.ca=t.ca,this.ciphers=t.ciphers,this.rejectUnauthorized=t.rejectUnauthorized,this.forceNode=t.forceNode,this.isReactNative=t.isReactNative,this.extraHeaders=t.extraHeaders,this.localAddress=t.localAddress}var o=n(21),i=n(8);t.exports=r,i(r.prototype),r.prototype.onError=function(t,e){var n=new Error(t);return n.type="TransportError",n.description=e,this.emit("error",n),this},r.prototype.open=function(){return"closed"!==this.readyState&&""!==this.readyState||(this.readyState="opening",this.doOpen()),this},r.prototype.close=function(){return"opening"!==this.readyState&&"open"!==this.readyState||(this.doClose(),this.onClose()),this},r.prototype.send=function(t){if("open"!==this.readyState)throw new Error("Transport not open");this.write(t)},r.prototype.onOpen=function(){this.readyState="open",this.writable=!0,this.emit("open")},r.prototype.onData=function(t){var e=o.decodePacket(t,this.socket.binaryType);this.onPacket(e)},r.prototype.onPacket=function(t){this.emit("packet",t)},r.prototype.onClose=function(){this.readyState="closed",this.emit("close")}},function(t,e,n){function r(t,n){var r="b"+e.packets[t.type]+t.data.data;return n(r)}function o(t,n,r){if(!n)return e.encodeBase64Packet(t,r);var o=t.data,i=new Uint8Array(o),s=new Uint8Array(1+o.byteLength);s[0]=v[t.type];for(var a=0;a<i.length;a++)s[a+1]=i[a];return r(s.buffer)}function i(t,n,r){if(!n)return e.encodeBase64Packet(t,r);var o=new FileReader;return o.onload=function(){e.encodePacket({type:t.type,data:o.result},n,!0,r)},o.readAsArrayBuffer(t.data)}function s(t,n,r){if(!n)return e.encodeBase64Packet(t,r);if(g)return i(t,n,r);var o=new Uint8Array(1);o[0]=v[t.type];var s=new k([o.buffer,t.data]);return r(s)}function a(t){try{t=d.decode(t,{strict:!1})}catch(e){return!1}return t}function c(t,e,n){for(var r=new Array(t.length),o=l(t.length,n),i=function(t,n,o){e(n,function(e,n){r[t]=n,o(e,r)})},s=0;s<t.length;s++)i(s,t[s],o)}var p,u=n(22),h=n(23),f=n(24),l=n(25),d=n(26);"undefined"!=typeof ArrayBuffer&&(p=n(27));var y="undefined"!=typeof navigator&&/Android/i.test(navigator.userAgent),m="undefined"!=typeof navigator&&/PhantomJS/i.test(navigator.userAgent),g=y||m;e.protocol=3;var v=e.packets={open:0,close:1,ping:2,pong:3,message:4,upgrade:5,noop:6},b=u(v),w={type:"error",data:"parser error"},k=n(28);e.encodePacket=function(t,e,n,i){"function"==typeof e&&(i=e,e=!1),"function"==typeof n&&(i=n,n=null);var a=void 0===t.data?void 0:t.data.buffer||t.data;if("undefined"!=typeof ArrayBuffer&&a instanceof ArrayBuffer)return o(t,e,i);if("undefined"!=typeof k&&a instanceof k)return s(t,e,i);if(a&&a.base64)return r(t,i);var c=v[t.type];return void 0!==t.data&&(c+=n?d.encode(String(t.data),{strict:!1}):String(t.data)),i(""+c)},e.encodeBase64Packet=function(t,n){var r="b"+e.packets[t.type];if("undefined"!=typeof k&&t.data instanceof k){var o=new FileReader;return o.onload=function(){var t=o.result.split(",")[1];n(r+t)},o.readAsDataURL(t.data)}var i;try{i=String.fromCharCode.apply(null,new Uint8Array(t.data))}catch(s){for(var a=new Uint8Array(t.data),c=new Array(a.length),p=0;p<a.length;p++)c[p]=a[p];i=String.fromCharCode.apply(null,c)}return r+=btoa(i),n(r)},e.decodePacket=function(t,n,r){if(void 0===t)return w;if("string"==typeof t){if("b"===t.charAt(0))return e.decodeBase64Packet(t.substr(1),n);if(r&&(t=a(t),t===!1))return w;var o=t.charAt(0);return Number(o)==o&&b[o]?t.length>1?{type:b[o],data:t.substring(1)}:{type:b[o]}:w}var i=new Uint8Array(t),o=i[0],s=f(t,1);return k&&"blob"===n&&(s=new k([s])),{type:b[o],data:s}},e.decodeBase64Packet=function(t,e){var n=b[t.charAt(0)];if(!p)return{type:n,data:{base64:!0,data:t.substr(1)}};var r=p.decode(t.substr(1));return"blob"===e&&k&&(r=new k([r])),{type:n,data:r}},e.encodePayload=function(t,n,r){function o(t){return t.length+":"+t}function i(t,r){e.encodePacket(t,!!s&&n,!1,function(t){r(null,o(t))})}"function"==typeof n&&(r=n,n=null);var s=h(t);return n&&s?k&&!g?e.encodePayloadAsBlob(t,r):e.encodePayloadAsArrayBuffer(t,r):t.length?void c(t,i,function(t,e){return r(e.join(""))}):r("0:")},e.decodePayload=function(t,n,r){if("string"!=typeof t)return e.decodePayloadAsBinary(t,n,r);"function"==typeof n&&(r=n,n=null);var o;if(""===t)return r(w,0,1);for(var i,s,a="",c=0,p=t.length;c<p;c++){var u=t.charAt(c);if(":"===u){if(""===a||a!=(i=Number(a)))return r(w,0,1);if(s=t.substr(c+1,i),a!=s.length)return r(w,0,1);if(s.length){if(o=e.decodePacket(s,n,!1),w.type===o.type&&w.data===o.data)return r(w,0,1);var h=r(o,c+i,p);if(!1===h)return}c+=i,a=""}else a+=u}return""!==a?r(w,0,1):void 0},e.encodePayloadAsArrayBuffer=function(t,n){function r(t,n){e.encodePacket(t,!0,!0,function(t){return n(null,t)})}return t.length?void c(t,r,function(t,e){var r=e.reduce(function(t,e){var n;return n="string"==typeof e?e.length:e.byteLength,t+n.toString().length+n+2},0),o=new Uint8Array(r),i=0;return e.forEach(function(t){var e="string"==typeof t,n=t;if(e){for(var r=new Uint8Array(t.length),s=0;s<t.length;s++)r[s]=t.charCodeAt(s);n=r.buffer}e?o[i++]=0:o[i++]=1;for(var a=n.byteLength.toString(),s=0;s<a.length;s++)o[i++]=parseInt(a[s]);o[i++]=255;for(var r=new Uint8Array(n),s=0;s<r.length;s++)o[i++]=r[s]}),n(o.buffer)}):n(new ArrayBuffer(0))},e.encodePayloadAsBlob=function(t,n){function r(t,n){e.encodePacket(t,!0,!0,function(t){var e=new Uint8Array(1);if(e[0]=1,"string"==typeof t){for(var r=new Uint8Array(t.length),o=0;o<t.length;o++)r[o]=t.charCodeAt(o);t=r.buffer,e[0]=0}for(var i=t instanceof ArrayBuffer?t.byteLength:t.size,s=i.toString(),a=new Uint8Array(s.length+1),o=0;o<s.length;o++)a[o]=parseInt(s[o]);if(a[s.length]=255,k){var c=new k([e.buffer,a.buffer,t]);n(null,c)}})}c(t,r,function(t,e){return n(new k(e))})},e.decodePayloadAsBinary=function(t,n,r){"function"==typeof n&&(r=n,n=null);for(var o=t,i=[];o.byteLength>0;){for(var s=new Uint8Array(o),a=0===s[0],c="",p=1;255!==s[p];p++){if(c.length>310)return r(w,0,1);c+=s[p]}o=f(o,2+c.length),c=parseInt(c);var u=f(o,0,c);if(a)try{u=String.fromCharCode.apply(null,new Uint8Array(u))}catch(h){var l=new Uint8Array(u);u="";for(var p=0;p<l.length;p++)u+=String.fromCharCode(l[p])}i.push(u),o=f(o,c)}var d=i.length;i.forEach(function(t,o){r(e.decodePacket(t,n,!0),o,d)})}},function(t,e){t.exports=Object.keys||function(t){var e=[],n=Object.prototype.hasOwnProperty;for(var r in t)n.call(t,r)&&e.push(r);return e}},function(t,e,n){function r(t){if(!t||"object"!=typeof t)return!1;if(o(t)){for(var e=0,n=t.length;e<n;e++)if(r(t[e]))return!0;return!1}if("function"==typeof Buffer&&Buffer.isBuffer&&Buffer.isBuffer(t)||"function"==typeof ArrayBuffer&&t instanceof ArrayBuffer||s&&t instanceof Blob||a&&t instanceof File)return!0;if(t.toJSON&&"function"==typeof t.toJSON&&1===arguments.length)return r(t.toJSON(),!0);for(var i in t)if(Object.prototype.hasOwnProperty.call(t,i)&&r(t[i]))return!0;return!1}var o=n(10),i=Object.prototype.toString,s="function"==typeof Blob||"undefined"!=typeof Blob&&"[object BlobConstructor]"===i.call(Blob),a="function"==typeof File||"undefined"!=typeof File&&"[object FileConstructor]"===i.call(File);t.exports=r},function(t,e){t.exports=function(t,e,n){var r=t.byteLength;if(e=e||0,n=n||r,t.slice)return t.slice(e,n);if(e<0&&(e+=r),n<0&&(n+=r),n>r&&(n=r),e>=r||e>=n||0===r)return new ArrayBuffer(0);for(var o=new Uint8Array(t),i=new Uint8Array(n-e),s=e,a=0;s<n;s++,a++)i[a]=o[s];return i.buffer}},function(t,e){function n(t,e,n){function o(t,r){if(o.count<=0)throw new Error("after called too many times");--o.count,t?(i=!0,e(t),e=n):0!==o.count||i||e(null,r)}var i=!1;return n=n||r,o.count=t,0===t?e():o}function r(){}t.exports=n},function(t,e){function n(t){for(var e,n,r=[],o=0,i=t.length;o<i;)e=t.charCodeAt(o++),e>=55296&&e<=56319&&o<i?(n=t.charCodeAt(o++),56320==(64512&n)?r.push(((1023&e)<<10)+(1023&n)+65536):(r.push(e),o--)):r.push(e);return r}function r(t){for(var e,n=t.length,r=-1,o="";++r<n;)e=t[r],e>65535&&(e-=65536,o+=d(e>>>10&1023|55296),e=56320|1023&e),o+=d(e);return o}function o(t,e){if(t>=55296&&t<=57343){if(e)throw Error("Lone surrogate U+"+t.toString(16).toUpperCase()+" is not a scalar value");return!1}return!0}function i(t,e){return d(t>>e&63|128)}function s(t,e){if(0==(4294967168&t))return d(t);var n="";return 0==(4294965248&t)?n=d(t>>6&31|192):0==(4294901760&t)?(o(t,e)||(t=65533),n=d(t>>12&15|224),n+=i(t,6)):0==(4292870144&t)&&(n=d(t>>18&7|240),n+=i(t,12),n+=i(t,6)),n+=d(63&t|128)}function a(t,e){e=e||{};for(var r,o=!1!==e.strict,i=n(t),a=i.length,c=-1,p="";++c<a;)r=i[c],p+=s(r,o);return p}function c(){if(l>=f)throw Error("Invalid byte index");var t=255&h[l];if(l++,128==(192&t))return 63&t;throw Error("Invalid continuation byte")}function p(t){var e,n,r,i,s;if(l>f)throw Error("Invalid byte index");if(l==f)return!1;if(e=255&h[l],l++,0==(128&e))return e;if(192==(224&e)){if(n=c(),s=(31&e)<<6|n,s>=128)return s;throw Error("Invalid continuation byte")}if(224==(240&e)){if(n=c(),r=c(),s=(15&e)<<12|n<<6|r,s>=2048)return o(s,t)?s:65533;throw Error("Invalid continuation byte")}if(240==(248&e)&&(n=c(),r=c(),i=c(),s=(7&e)<<18|n<<12|r<<6|i,s>=65536&&s<=1114111))return s;throw Error("Invalid UTF-8 detected")}function u(t,e){e=e||{};var o=!1!==e.strict;h=n(t),f=h.length,l=0;for(var i,s=[];(i=p(o))!==!1;)s.push(i);return r(s)}/*! https://mths.be/utf8js v2.1.2 by @mathias */
var h,f,l,d=String.fromCharCode;t.exports={version:"2.1.2",encode:a,decode:u}},function(t,e){!function(){"use strict";for(var t="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",n=new Uint8Array(256),r=0;r<t.length;r++)n[t.charCodeAt(r)]=r;e.encode=function(e){var n,r=new Uint8Array(e),o=r.length,i="";for(n=0;n<o;n+=3)i+=t[r[n]>>2],i+=t[(3&r[n])<<4|r[n+1]>>4],i+=t[(15&r[n+1])<<2|r[n+2]>>6],i+=t[63&r[n+2]];return o%3===2?i=i.substring(0,i.length-1)+"=":o%3===1&&(i=i.substring(0,i.length-2)+"=="),i},e.decode=function(t){var e,r,o,i,s,a=.75*t.length,c=t.length,p=0;"="===t[t.length-1]&&(a--,"="===t[t.length-2]&&a--);var u=new ArrayBuffer(a),h=new Uint8Array(u);for(e=0;e<c;e+=4)r=n[t.charCodeAt(e)],o=n[t.charCodeAt(e+1)],i=n[t.charCodeAt(e+2)],s=n[t.charCodeAt(e+3)],h[p++]=r<<2|o>>4,h[p++]=(15&o)<<4|i>>2,h[p++]=(3&i)<<6|63&s;return u}}()},function(t,e){function n(t){return t.map(function(t){if(t.buffer instanceof ArrayBuffer){var e=t.buffer;if(t.byteLength!==e.byteLength){var n=new Uint8Array(t.byteLength);n.set(new Uint8Array(e,t.byteOffset,t.byteLength)),e=n.buffer}return e}return t})}function r(t,e){e=e||{};var r=new i;return n(t).forEach(function(t){r.append(t)}),e.type?r.getBlob(e.type):r.getBlob()}function o(t,e){return new Blob(n(t),e||{})}var i="undefined"!=typeof i?i:"undefined"!=typeof WebKitBlobBuilder?WebKitBlobBuilder:"undefined"!=typeof MSBlobBuilder?MSBlobBuilder:"undefined"!=typeof MozBlobBuilder&&MozBlobBuilder,s=function(){try{var t=new Blob(["hi"]);return 2===t.size}catch(e){return!1}}(),a=s&&function(){try{var t=new Blob([new Uint8Array([1,2])]);return 2===t.size}catch(e){return!1}}(),c=i&&i.prototype.append&&i.prototype.getBlob;"undefined"!=typeof Blob&&(r.prototype=Blob.prototype,o.prototype=Blob.prototype),t.exports=function(){return s?a?Blob:o:c?r:void 0}()},function(t,e){e.encode=function(t){var e="";for(var n in t)t.hasOwnProperty(n)&&(e.length&&(e+="&"),e+=encodeURIComponent(n)+"="+encodeURIComponent(t[n]));return e},e.decode=function(t){for(var e={},n=t.split("&"),r=0,o=n.length;r<o;r++){var i=n[r].split("=");e[decodeURIComponent(i[0])]=decodeURIComponent(i[1])}return e}},function(t,e){t.exports=function(t,e){var n=function(){};n.prototype=e.prototype,t.prototype=new n,t.prototype.constructor=t}},function(t,e){"use strict";function n(t){var e="";do e=s[t%a]+e,t=Math.floor(t/a);while(t>0);return e}function r(t){var e=0;for(u=0;u<t.length;u++)e=e*a+c[t.charAt(u)];return e}function o(){var t=n(+new Date);return t!==i?(p=0,i=t):t+"."+n(p++)}for(var i,s="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_".split(""),a=64,c={},p=0,u=0;u<a;u++)c[s[u]]=u;o.encode=n,o.decode=r,t.exports=o},function(t,e,n){(function(e){function r(){}function o(){return"undefined"!=typeof self?self:"undefined"!=typeof window?window:"undefined"!=typeof e?e:{}}function i(t){if(s.call(this,t),this.query=this.query||{},!c){var e=o();c=e.___eio=e.___eio||[]}this.index=c.length;var n=this;c.push(function(t){n.onData(t)}),this.query.j=this.index,"function"==typeof addEventListener&&addEventListener("beforeunload",function(){n.script&&(n.script.onerror=r)},!1)}var s=n(19),a=n(30);t.exports=i;var c,p=/\n/g,u=/\\n/g;a(i,s),i.prototype.supportsBinary=!1,i.prototype.doClose=function(){this.script&&(this.script.parentNode.removeChild(this.script),this.script=null),this.form&&(this.form.parentNode.removeChild(this.form),this.form=null,this.iframe=null),s.prototype.doClose.call(this)},i.prototype.doPoll=function(){var t=this,e=document.createElement("script");this.script&&(this.script.parentNode.removeChild(this.script),this.script=null),e.async=!0,e.src=this.uri(),e.onerror=function(e){t.onError("jsonp poll error",e)};var n=document.getElementsByTagName("script")[0];n?n.parentNode.insertBefore(e,n):(document.head||document.body).appendChild(e),this.script=e;var r="undefined"!=typeof navigator&&/gecko/i.test(navigator.userAgent);r&&setTimeout(function(){var t=document.createElement("iframe");document.body.appendChild(t),document.body.removeChild(t)},100)},i.prototype.doWrite=function(t,e){function n(){r(),e()}function r(){if(o.iframe)try{o.form.removeChild(o.iframe)}catch(t){o.onError("jsonp polling iframe removal error",t)}try{var e='<iframe src="javascript:0" name="'+o.iframeId+'">';i=document.createElement(e)}catch(t){i=document.createElement("iframe"),i.name=o.iframeId,i.src="javascript:0"}i.id=o.iframeId,o.form.appendChild(i),o.iframe=i}var o=this;if(!this.form){var i,s=document.createElement("form"),a=document.createElement("textarea"),c=this.iframeId="eio_iframe_"+this.index;s.className="socketio",s.style.position="absolute",s.style.top="-1000px",s.style.left="-1000px",s.target=c,s.method="POST",s.setAttribute("accept-charset","utf-8"),a.name="d",s.appendChild(a),document.body.appendChild(s),this.form=s,this.area=a}this.form.action=this.uri(),r(),t=t.replace(u,"\\\n"),this.area.value=t.replace(p,"\\n");try{this.form.submit()}catch(h){}this.iframe.attachEvent?this.iframe.onreadystatechange=function(){"complete"===o.iframe.readyState&&n()}:this.iframe.onload=n}}).call(e,function(){return this}())},function(t,e,n){function r(t){var e=t&&t.forceBase64;e&&(this.supportsBinary=!1),this.perMessageDeflate=t.perMessageDeflate,this.usingBrowserWebSocket=o&&!t.forceNode,this.protocols=t.protocols,this.usingBrowserWebSocket||(l=i),s.call(this,t)}var o,i,s=n(20),a=n(21),c=n(29),p=n(30),u=n(31),h=n(3)("engine.io-client:websocket");if("undefined"==typeof self)try{i=n(34)}catch(f){}else o=self.WebSocket||self.MozWebSocket;var l=o||i;t.exports=r,p(r,s),r.prototype.name="websocket",r.prototype.supportsBinary=!0,r.prototype.doOpen=function(){if(this.check()){var t=this.uri(),e=this.protocols,n={agent:this.agent,perMessageDeflate:this.perMessageDeflate};n.pfx=this.pfx,n.key=this.key,n.passphrase=this.passphrase,n.cert=this.cert,n.ca=this.ca,n.ciphers=this.ciphers,n.rejectUnauthorized=this.rejectUnauthorized,this.extraHeaders&&(n.headers=this.extraHeaders),this.localAddress&&(n.localAddress=this.localAddress);try{this.ws=this.usingBrowserWebSocket&&!this.isReactNative?e?new l(t,e):new l(t):new l(t,e,n)}catch(r){return this.emit("error",r)}void 0===this.ws.binaryType&&(this.supportsBinary=!1),this.ws.supports&&this.ws.supports.binary?(this.supportsBinary=!0,this.ws.binaryType="nodebuffer"):this.ws.binaryType="arraybuffer",this.addEventListeners()}},r.prototype.addEventListeners=function(){var t=this;this.ws.onopen=function(){t.onOpen()},this.ws.onclose=function(){t.onClose()},this.ws.onmessage=function(e){t.onData(e.data)},this.ws.onerror=function(e){t.onError("websocket error",e)}},r.prototype.write=function(t){function e(){n.emit("flush"),setTimeout(function(){n.writable=!0,n.emit("drain")},0)}var n=this;this.writable=!1;for(var r=t.length,o=0,i=r;o<i;o++)!function(t){a.encodePacket(t,n.supportsBinary,function(o){if(!n.usingBrowserWebSocket){var i={};if(t.options&&(i.compress=t.options.compress),n.perMessageDeflate){var s="string"==typeof o?Buffer.byteLength(o):o.length;s<n.perMessageDeflate.threshold&&(i.compress=!1)}}try{n.usingBrowserWebSocket?n.ws.send(o):n.ws.send(o,i)}catch(a){h("websocket closed before onclose event")}--r||e()})}(t[o])},r.prototype.onClose=function(){s.prototype.onClose.call(this)},r.prototype.doClose=function(){"undefined"!=typeof this.ws&&this.ws.close()},r.prototype.uri=function(){var t=this.query||{},e=this.secure?"wss":"ws",n="";this.port&&("wss"===e&&443!==Number(this.port)||"ws"===e&&80!==Number(this.port))&&(n=":"+this.port),this.timestampRequests&&(t[this.timestampParam]=u()),this.supportsBinary||(t.b64=1),t=c.encode(t),t.length&&(t="?"+t);var r=this.hostname.indexOf(":")!==-1;return e+"://"+(r?"["+this.hostname+"]":this.hostname)+n+this.path+t},r.prototype.check=function(){return!(!l||"__initialize"in l&&this.name===r.prototype.name)}},function(t,e){},function(t,e){var n=[].indexOf;t.exports=function(t,e){if(n)return t.indexOf(e);for(var r=0;r<t.length;++r)if(t[r]===e)return r;return-1}},function(t,e,n){"use strict";function r(t,e,n){this.io=t,this.nsp=e,this.json=this,this.ids=0,this.acks={},this.receiveBuffer=[],this.sendBuffer=[],this.connected=!1,this.disconnected=!0,this.flags={},n&&n.query&&(this.query=n.query),this.io.autoConnect&&this.open()}var o="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(t){return typeof t}:function(t){return t&&"function"==typeof Symbol&&t.constructor===Symbol&&t!==Symbol.prototype?"symbol":typeof t},i=n(7),s=n(8),a=n(37),c=n(38),p=n(39),u=n(3)("socket.io-client:socket"),h=n(29),f=n(23);t.exports=e=r;var l={connect:1,connect_error:1,connect_timeout:1,connecting:1,disconnect:1,error:1,reconnect:1,reconnect_attempt:1,reconnect_failed:1,reconnect_error:1,reconnecting:1,ping:1,pong:1},d=s.prototype.emit;s(r.prototype),r.prototype.subEvents=function(){if(!this.subs){var t=this.io;this.subs=[c(t,"open",p(this,"onopen")),c(t,"packet",p(this,"onpacket")),c(t,"close",p(this,"onclose"))]}},r.prototype.open=r.prototype.connect=function(){return this.connected?this:(this.subEvents(),this.io.open(),"open"===this.io.readyState&&this.onopen(),this.emit("connecting"),this)},r.prototype.send=function(){var t=a(arguments);return t.unshift("message"),this.emit.apply(this,t),this},r.prototype.emit=function(t){if(l.hasOwnProperty(t))return d.apply(this,arguments),this;var e=a(arguments),n={type:(void 0!==this.flags.binary?this.flags.binary:f(e))?i.BINARY_EVENT:i.EVENT,data:e};return n.options={},n.options.compress=!this.flags||!1!==this.flags.compress,"function"==typeof e[e.length-1]&&(u("emitting packet with ack id %d",this.ids),this.acks[this.ids]=e.pop(),n.id=this.ids++),this.connected?this.packet(n):this.sendBuffer.push(n),this.flags={},this},r.prototype.packet=function(t){t.nsp=this.nsp,this.io.packet(t)},r.prototype.onopen=function(){if(u("transport is open - connecting"),"/"!==this.nsp)if(this.query){var t="object"===o(this.query)?h.encode(this.query):this.query;u("sending connect packet with query %s",t),this.packet({type:i.CONNECT,query:t})}else this.packet({type:i.CONNECT})},r.prototype.onclose=function(t){u("close (%s)",t),this.connected=!1,this.disconnected=!0,delete this.id,this.emit("disconnect",t)},r.prototype.onpacket=function(t){var e=t.nsp===this.nsp,n=t.type===i.ERROR&&"/"===t.nsp;if(e||n)switch(t.type){case i.CONNECT:this.onconnect();break;case i.EVENT:this.onevent(t);break;case i.BINARY_EVENT:this.onevent(t);break;case i.ACK:this.onack(t);break;case i.BINARY_ACK:this.onack(t);break;case i.DISCONNECT:this.ondisconnect();break;case i.ERROR:this.emit("error",t.data)}},r.prototype.onevent=function(t){var e=t.data||[];u("emitting event %j",e),null!=t.id&&(u("attaching ack callback to event"),e.push(this.ack(t.id))),this.connected?d.apply(this,e):this.receiveBuffer.push(e)},r.prototype.ack=function(t){var e=this,n=!1;return function(){if(!n){n=!0;var r=a(arguments);u("sending ack %j",r),e.packet({type:f(r)?i.BINARY_ACK:i.ACK,id:t,data:r})}}},r.prototype.onack=function(t){var e=this.acks[t.id];"function"==typeof e?(u("calling ack %s with %j",t.id,t.data),e.apply(this,t.data),delete this.acks[t.id]):u("bad ack %s",t.id)},r.prototype.onconnect=function(){this.connected=!0,this.disconnected=!1,this.emit("connect"),this.emitBuffered()},r.prototype.emitBuffered=function(){var t;for(t=0;t<this.receiveBuffer.length;t++)d.apply(this,this.receiveBuffer[t]);for(this.receiveBuffer=[],t=0;t<this.sendBuffer.length;t++)this.packet(this.sendBuffer[t]);this.sendBuffer=[]},r.prototype.ondisconnect=function(){u("server disconnect (%s)",this.nsp),this.destroy(),this.onclose("io server disconnect")},r.prototype.destroy=function(){if(this.subs){for(var t=0;t<this.subs.length;t++)this.subs[t].destroy();this.subs=null}this.io.destroy(this)},r.prototype.close=r.prototype.disconnect=function(){return this.connected&&(u("performing disconnect (%s)",this.nsp),this.packet({type:i.DISCONNECT})),this.destroy(),this.connected&&this.onclose("io client disconnect"),this},r.prototype.compress=function(t){return this.flags.compress=t,this},r.prototype.binary=function(t){return this.flags.binary=t,this}},function(t,e){function n(t,e){var n=[];e=e||0;for(var r=e||0;r<t.length;r++)n[r-e]=t[r];return n}t.exports=n},function(t,e){"use strict";function n(t,e,n){return t.on(e,n),{destroy:function(){t.removeListener(e,n)}}}t.exports=n},function(t,e){var n=[].slice;t.exports=function(t,e){if("string"==typeof e&&(e=t[e]),"function"!=typeof e)throw new Error("bind() requires a function");var r=n.call(arguments,2);return function(){return e.apply(t,r.concat(n.call(arguments)))}}},function(t,e){function n(t){t=t||{},this.ms=t.min||100,this.max=t.max||1e4,this.factor=t.factor||2,this.jitter=t.jitter>0&&t.jitter<=1?t.jitter:0,this.attempts=0}t.exports=n,n.prototype.duration=function(){var t=this.ms*Math.pow(this.factor,this.attempts++);if(this.jitter){var e=Math.random(),n=Math.floor(e*this.jitter*t);t=0==(1&Math.floor(10*e))?t-n:t+n}return 0|Math.min(t,this.max)},n.prototype.reset=function(){this.attempts=0},n.prototype.setMin=function(t){this.ms=t},n.prototype.setMax=function(t){this.max=t},n.prototype.setJitter=function(t){this.jitter=t}}])});
//# sourceMappingURL=socket.io.js.map
.fr {
float : right;
}
.fl {
float : left;
}
.msg {
background-color : #f0f0f5;
border : grey solid 1px;
margin-top : -1px;
padding : 2px;
margin-right : 3px;
margin-left : 3px;
}
.nobreak {
display : inline;
white-space : nowrap;
word-break : keep-all;
}
.tbox {
overflow : scroll;
border : lightgrey solid 1px;
padding : 0;
max-height : 26px;
min-height : 26px;
height : 26px;
font-weight : bold;
overflow : hidden;
resize : none;
}
.emoii {
width : 22px;
max-width : 22px;
height : 22px;
margin : 0;
padding : 5px;
}
.hid {
display : none;
}
.noflow {
overflow : hidden;
}
div {
line-height : 20px;
}
img {
vertical-align : middle;
}
.break {
overflow : auto;
overflow-wrap : break-word;
overflow-x : hidden;
overflow-wrap : break-word;
}
.ui-icon-adjust:after {
background-image : url("");
background-repeat : no-repeat;
background-position : 4px 3px;
float : left;
}
[data-role="icon"]:after {
background-image : url("");
background-repeat : no-repeat;
background-position : 4px 3px;
float : left;
}
* {
font-family : Verdana, Geneva, Tahoma, sans-serif;
font-weight : bold !important ;
text-shadow : none !important ;
font-size : 13.8px !important ;
}
.u-ico {
padding-right : 2px;
margin-top : 2px;
max-height : 16px;
}
html, body {
height : 100%;
}
.ui-tabs-nav {
padding : 0;
}
.ui-tabs-panel {
padding : 0;
}
.darker {
background-color : #33333a;
}
.emoi {
width : 18px;
max-width : 18px;
height : auto;
max-height : 18px;
}
.unread {
background-color : #FFC89D !important ;
}
div {
line-height : 20px;
}
.b {
border : grey solid 1px;
}
.bb {
border : grey solid 2px;
}
table, th, td {
border : 0;
}
th, td {
padding : 0;
}
table {
border-spacing : 0;
border-collapse : collapse;
}
.ui-popup-container {
margin : 0;
padding : 0;
}
.animating {
animation : animate 1s cubic-bezier(0,1,1,0);
}
.mini {
font-size : 90% !important ;
}
.corner {
border-radius : 5px;
}
.minix {
font-size : 80% !important ;
}
@keyframes animate {
from {
transform : scale(1);
}
to {
transform : scale(1.5);
}
}
.nosel, .u-ico, .u-pic, .tago {
user-select : none;
cursor : default;
}
.ui-dialog-contain {
width : 92.5%;
max-width : 500px;
margin : 0% auto 15px auto;
padding : 0;
position : relative;
top : 2px;
}
.center {
margin : 0 auto;
}
.dots {
display : inline-block;
white-space : nowrap;
overflow : hidden !important ;
text-overflow : ellipsis;
max-width : 100%;
}
.ui-tabs .ui-tabs-panel {
padding : 0;
margin : 0;
}
.ui-widget-overlay {
background-color : black;
background-image : none;
opacity : 0.119999997317790985107421875;
z-index : 1040;
}
.ui-dialog .ui-dialog-content {
padding : 0;
}
.ui-tabs-anchor {
padding : 0;
}
.hgreen {
background-color : darkseagreen;
}
.hred {
background-color : indianred;
}
.borderg {
border : lavender solid 1px;
}
.border {
border : black solid 1px;
}
nopadding {
padding : 0;
margin : 0;
}
.fitimg {
background-size : contain;
background-repeat : no-repeat;
background-position : 50% 50%;
}
.ui-dialog .ui-dialog-titlebar {
padding : 5px;
}
.bord {
border : dodgerblue solid 1px !important ;
}
.uzr {
margin-left : 2px !important ;
border-radius : 5px;
}
html {
height : 100vh;
width : 100vw;
}
.ui-state-default .ui-tabs-anchor {
padding : 5px !important ;
}
.mw {
width : 380px;
max-width : 380px;
min-width : 380px;
}
.mww {
width : 260px;
max-width : 260px;
min-width : 260px;
}
.pn2 {
width : 99%;
max-width : 320px;
height : 80%;
left : 5px;
float : right;
z-index : 2;
margin : 0;
position : absolute;
}
.panel-heading {
padding : 6px;
}
.fa {
text-align : left;
}
.modal-header {
padding : 5px;
}
.badge {
padding : 0 3px;
}
.bx {
margin-top : -8px;
}
.panel-body {
padding : 2px;
height : auto;
}
button.btn {
padding : 5px 5px;
}
.tab-pane {
padding : 0;
}
.d2 {
padding-bottom : 2px;
}
.popover-content {
padding : 1px;
}
.bubbles {
    width: 99%;
    padding-left: 20px;
    position: absolute;
    margin-bottom: 30px;
    bottom: 0;
    display: inline-block;
    text-align: center;
}
.bubble{
    -webkit-animation:short-bubble 1500ms linear ;
    animation:short-bubble 1500ms linear ;
    -webkit-animation-fill-mode:forwards;
    animation-fill-mode:forwards;
    height:20px;
    width:20px;
    border:1px solid rgba(240,240,240,0.5);
    border-radius:50%;
}

.b2{
    -webkit-animation:medium-bubble 5000ms linear ;
    animation:medium-bubble 5000ms linear ;
    -webkit-animation-fill-mode:forwards;
    animation-fill-mode:forwards;
/*    margin-left:-7px;*/
    margin-top:25px;
    height:20px;
    width:20px;
}

.b3{
    -webkit-animation-duration:3500ms;
    animation-duration:3500ms;
/*    margin-left:-5px;*/
    margin-bottom:10px;
}

.b4{
    -webkit-animation-duration:2000ms;
    animation-duration:2000ms;
    -webkit-animation-fill-mode:forwards;
    animation-fill-mode:forwards;
    margin:0 0 40px -9px;
    height:20px;
    width:20px;
}

.b5{
    -webkit-animation:medium-bubble 3000ms linear ;
    animation:medium-bubble 3000ms linear ;
    -webkit-animation-fill-mode:forwards;
    animation-fill-mode:forwards;
    margin-left:-1px;
    margin-top:100px;
    height:20px;
    width:20px;
}

.b6{
    -webkit-animation-duration:3000ms;
    animation-duration:3000ms;
/*    margin-left:-8px;*/
    margin-bottom:50px;
}

.b7{
    -webkit-animation-duration:6000ms;
    animation-duration:6000ms;
/*    margin-left:-3px;*/
    margin-bottom:50px;
    height:20px;
    width:20px;
}

.b8{
    -webkit-animation:medium-bubble 2000ms linear ;
    -webkit-animation-fill-mode:forwards;
    animation:medium-bubble 2000ms linear ;
    animation-fill-mode:forwards;
/*    margin-left:-13px;*/
    margin-bottom:30px;
}

@-webkit-keyframes short-bubble{
    0%{ -webkit-transform:translate3d(5px, 0, 0);opacity:0; }
    13%{ -webkit-transform:translate3d(2px, -20px, 0); opacity:1; }
    20%{ -webkit-transform:translate3d(5px, -40px, 0) scale(1.2); }
    30%{ -webkit-transform:translate3d(0, -60px, 0); }
    40%{ -webkit-transform:translate3d(8px, -80px, 0); }
    50%{ -webkit-transform:translate3d(3px, -100px, 0); }
    60%{ -webkit-transform:translate3d(8px, -120px, 0); }
    70%{ opacity:0.4; }
    80%, 100%{ -webkit-transform:translate3d(0,-200px, 0); opacity:0; }
}

@keyframes short-bubble{
    0%{ transform:translate3d(5px, 0, 0);opacity:0; }
    13%{ transform:translate3d(2px, -20px, 0); opacity:1; }
    20%{ transform:translate3d(5px, -40px, 0) scale(1.2); }
    30%{ transform:translate3d(0px, -60px, 0); }
    40%{ transform:translate3d(8px, -80px, 0); }
    50%{ transform:translate3d(3px, -100px, 0); }
    60%{ transform:translate3d(8px, -120px, 0); }
    70%{ opacity:0.4; }
    80%, 100%{ transform:translate3d(0,-200px, 0); opacity:0; }
}

@-webkit-keyframes medium-bubble{
    0%{ -webkit-transform:translate3d(0, 0, 0); opacity:0;}
    5%{ -webkit-transform:translate3d(4px, -20px, 0); opacity:1;}
    10%{ -webkit-transform:translate3d(2px, -40px, 0) rotate(10deg); }
    20%{ -webkit-transform:translate3d(7px, -80px, 0) rotate(14deg) scale(0.7); }
    30%{ -webkit-transform:translate3d(5px, -120px, 0) rotate(15deg); }
    40%{ -webkit-transform:translate3d(1px, -160px, 0) rotate(20deg); }
    50%{ -webkit-transform:translate3d(2px, -200px, 0) rotate(18deg) scale(1.1); }
    60%{ -webkit-transform:translate3d(-3px, -240px, 0) rotate(22deg); opacity:0.4; }
    100%{ -webkit-transform:translate3d(0, -400px, 0); opacity:0; }
}

@keyframes medium-bubble{
    0%{ transform:translate3d(0, 0, 0); opacity:0;}
    5%{ transform:translate3d(4px, -20px, 0); opacity:1;}
    10%{ transform:translate3d(2px, -40px, 0) rotate(10deg); }
    20%{ transform:translate3d(7px, -80px, 0) rotate(14deg) scale(0.7); }
    30%{ transform:translate3d(5px, -120px, 0) rotate(15deg); }
    40%{ transform:translate3d(1px, -160px, 0) rotate(20deg); }
    50%{ transform:translate3d(2px, -200px, 0) rotate(18deg) scale(1.1); }
    60%{ transform:translate3d(-3px, -240px, 0) rotate(22deg); opacity:0.4; }
    100%{ transform:translate3d(0, -400px, 0); opacity:0; }
}
.bubbles img{
    height:20px;
    width:20px;
	opacity:0;
}



#sultan10{
    border-top: 3px solid #F7F7F7;
    border-bottom: 3px solid #F7F7F7;
    margin-bottom: 3px;
    border-radius: 15px;
}
.s1.fa.fa-user.label.badgex.label-as-badge.label-success {background-color: #c86184!important;}
.fr.borderg, .fr.borderg {border: 1px solid #108378;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.label-primary.mini.fl, .border-radius {border: 2px solid #;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.room.borderg.hand.nosel.fl, .border-radius {border: 1px solid #c86184;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.btn-sm, .btn-sm {border: 1px solid #28bbad;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.hand.nosel.fl.uzr.border, .hand.nosel.fl.uzr.border {border: 1px solid #c86184;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.uzr.fl.corner.borderg.mm, .uzr.fl.corner.borderg.mm {border: 1px solid #c86184;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
.label.tc.border.btn.fl, .label.tc.border.btn.fl {border: 1px solid #c86184;font-family: 'jazeera',FontAwesome;border-radius: 15px 0px 15px 0px;}
ul.nav.nav-tabs.fl li a:hover {background-color: #108378;color: white;}
ul.nav.nav-tabs.fl li {width: 33.3%;border-top: 2px solid #108378;border-radius: 15px 15px 0px 0px;background-color: #FFFFFF;border-bottom: 3px solid #108378;}
ul.nav.nav-tabs.fl li a {font-family: 'jazeera',FontAwesome;font-size: 13px!important;padding: 6px!important;text-align: center!important;border-radius: 15px 15px 0px 0px;width: 100%;color: #32d3c3;}

div#tlogins {
    border: 2px solid #31d4c4;
    border-radius: 20px 20px 0px 0px;
}
a.label.label-primary.fl {
    height: 35px;
    border-radius: 0px 0px 0px 0px!important;
    padding: 8px!important;
    border: 2px solid #149e90;
}
a.label.label-primary.fl img.fl {
    margin-top: -3px;
    border-radius: 10px 0px;
}
a.label.label-primary.fl {
    height: 40px;
    border-radius: 0px 0px 0px 0px!important;
    padding: 8px!important;
    border: 2px solid #149e90;
}
.sultan9 {height: 30px;width: 22%; margin: 2px;}
.sultan11 {
background-color: #fff;
border-radius: 15px 15px 15px 15px;
font-family: 'jazeera',FontAwesome;
padding: 2px 10px 2px 10px; margin:7px 10px 7px 10px;
    
}
#sultan8 {
    margin-bottom: 2px;
    font-family: 'jazeera-light',FontAwesome;
    background-color: #EB8090;
    height: 28px;
    color: #f9f9f9;
    border-radius: 5px 5px 5px 5px;
    border-bottom: 2px solid #c86184;
    border-top: 2px solid #c86184;
    padding-bottom: 2px!important;
}


label.fl.label.loginstat.label-success {
    border-radius: 15px 0px 15px 0px!important;
    font-family: 'jazeera',FontAwesome;
    height: 23px;
    float: initial;
    display: inline-flex;
}
.lonline.light.break .hand.nosel.fl.uzr.border .fl .fl .fl span.corner.u-topic.dots {
    border-radius: 0px 0px 15px 15px!important;
}
button.btn.fr.btn-success.fa.fa-refresh {
padding: 4px 5px;
background-color: #c86184!important;
background-image: none;
border: 2px solid transparent;
margin-top: -22px!important;
border-radius: 50px;
}
#sultanm1 {
    background-color: #dc2c2c;
    color: white;
    padding-right: 8px;
    padding-left: 5px;
    border-radius: 15px 0px;
    padding-top: 0;
    padding-bottom: 2px;
    font-family: 'jazeera',FontAwesome;
    margin: 4px;
}
#sultanm2 {
    color: white;
    background-color: rgb(12, 12, 14);
    padding: 0;
    padding-right: 10px;
    padding-left: 5px;
    border-radius: 0px 15px;
    border: 1px solid #ff0000;
    margin: 10px;
}
.sultan9 {height: 30px;width: 22%; margin: 2px;}
.sultan11 {
background-color: #fff;
border-radius: 15px 15px 15px 15px;
font-family: 'jazeera',FontAwesome;
padding: 2px 10px 2px 10px; margin:7px 10px 7px 10px;
    
}
#sultan5{margin-left: 8%;margin-bottom: 2px;font-family: 'jazeera-light',FontAwesome;background-color: rgb(255, 235, 247);margin-top: -5px;height: 24px;color: #c10c6b;text-shadow: 2px 0px 8px rgba(243, 8, 144, 0.32) , 0px 2px 10px #fff !important;border-radius: 5px 5px 5px 5px;}
#sultan25 {
    margin-left: 2px;
    margin-bottom: -4px;
    font-family: 'jazeera-light',FontAwesome;
    background-color: rgb(255, 235, 247);
    margin-top: 1px;
    height: 24px;
    color: #c86184;
    text-shadow: 2px 0px 8px rgba(19, 18, 18, 0.32) , 0px 2px 10px #fff !important;
    border-radius: 5px 5px 5px 5px;
}
div#tlogins .fr.borderg {
    font-size: 10px!important;
}
div#tlogins .fr.borderg a {
    font-size: 10px!important;
}

.sultan9 {height: 30px;width: 22%; margin: 2px;}
.sultan111 {
font-family: 'jazeera',FontAwesome;
}
  
div#l1  input#u1 {border-radius: 15px 15px 0px 0px;border: 1px solid #e1e0e0;width: 99%;margin-top: 3px;margin-left:1px;text-align: center;font-family: 'jazeera-light',FontAwesome;}
div#l1 button {border-radius: 0px 0px 15px 15px;width: 99%;height: 30px;}
div#l3 button {border-radius: 15px;width: 99%;height: 30px;margin-left:1px;}
div#l2 button {border-radius: 15px;width: 70%;height: 30px;}
div#l2 input#pass1, div#l2 input#u2, div#l3 input#pass2, div#l3 input#u3{width: 49%;padding: 0px!important;float: right;margin: 2px 5px 2px 0px;;text-align: center;font-family: 'jazeera-light',FontAwesome;}
div#l2 input#u2, div#l3 input#u3{margin-left: -6px;border-radius: 0px 15px 15px 0px;border: 1px solid #e1e0e0;}
div#l2 input#pass1, div#l3 input#pass2 {border-radius: 15px 0px 0px 15px;border: 1px solid #e1e0e0;}
div#l2 , div#l3 {padding: 2px!important;}
div#l1 {height: 80px;margin: 0px 1px -18px 1px;padding: 0px!important;}
div#l3 br , div#l2 br {display: none;}
div#l2 ,div#l3, div#l1 {
    border-bottom: 2px solid;
    margin-bottom: 2px;
    border-top: 0px solid;
    margin-top: 0px;
    border-color: #108378;
    border-radius: 15px;
    height: 69px;
}


}

img.fitimg.fl.u-pic {
    border-radius: 15px 0;
    border: 1.5px solid #5b5959;
    background-size: cover;
}


}
label.fl.label.loginstat.label-success, .fr.borderg, .label.label.label-primary.mini.fl {
    margin-top: 5px;
  }
  .room.borderg.hand.nosel.fl img.fl.u-pic {
    border-radius: 15px 15px 15px 15px;
  }
  .sultan111, div#d2 {
    background-repeat: no-repeat;
    background-size: contain;
    background-image: url();
    background-color: #ffffff;
  }
  .lonline.light.break{background-image: url();background-size: inherit;border-top:5px groove #108378;padding-top:5px}
  .sultan111,div#d2{background-repeat: no-repeat;background-size: contain;background-image: url();background-color:#ffffff}a.label.label-primary.fl{height:35px;border-radius:19px 19px 0 0!important;padding:8px!important;border:2px solid #4bafa5}
}

label.fl.label.loginstat.label-success, .fr.borderg, .label.label.label-primary.mini.fl {
    margin-top: 5px;
    height: 27px;
}
label.fl.label.loginstat.label-success {
    border-radius: 5px 5px 5px 5px!important;
    font-family: 'jazeera',FontAwesome;
    height: 22px;
    display: inline-flex;
}
.fl.label.loginstat.label-success, .fl.label.loginstat.label-info {
    color: #c86184;
    border: 1px solid #e2e0e0;
    border-radius: 5px 5px 5px 5px;
    margin-top: 1px;
    background-color: #FFFFFF!important;
}
.fr.co {
    transform: rotate(90deg);
    height: 10px;
    width: 16px!important;
    margin-top: 4px;
}

.lonline.light.break .hand.nosel.fa.uzr.border >.fa {
    float: right;
    text-align: right;
}

img.fitimg.fl.u-pic {
    border: 1px solid #c86184;
    border-radius: 19px;
}
label.label.tc.border.btn.fl {
    border-radius: 40px 40px 0px 40px;
}
.room.borderg.hand.nosel.fl img.fl.u-pic {
    border-radius: 15px 15px 15px 15px;
}
.label.tc.border.btn.fl, .label.tc.border.btn.fl {
    border: 1px solid #c9d3e4;
    border-radius: 5px 5px 5px 5px;
}
label.tc {
    border-radius: 15px 15px 0px 0px;
}
body, .nosel.fl.bg, .tablebox.footer.fl.light, .break.fr {
    background-image: url();
}
.u-msg.break.fl {
    color: #AD2856;
}
.hand.nosel.fl.uzr.border {
    border-right: 1px solid #d0046f;
    border-left: 1px solid #d0046f;
    border-radius: 15px;
    margin: 2px;
    margin-top: 2px;
    margin-left: 2px;
}
.hand.nosel.fl.uzr.border, .hand.nosel.fl.uzr.border {
    border: 1px solid #FFE0F6;
    border-radius: 5px 5px 5px 5px;
}
.hand.nosel.fl.uzr.border, .hand.nosel.fl.uzr.border {
    border: 1px solid #FFE0F6;
    font-family: 'jazeera',FontAwesome;
    border-radius: 5px 5px 10px 10px;
}

element.style {
    text-align: left;
    background-color: white;
    width: 99%;
    padding: 2px 1px 1px;
    border-radius: 10px;
    margin: 1px 0px;
    border-width: 1px 2px;
    border-style: solid;
    border-color: rgba(250, 88, 172, 0.38) rgb(250, 88, 172);
}
<!DOCTYPE HTML>
<html lang="ar" hreflang="ar-sa"> 

	<head>

		<link rel="canonical" href="https://raw.githubusercontent.com/abbassaad995/test.css/master/http:/iraqechat1.com" />
		<meta content="text/html charset=utf-8" http-equiv="Content-Type">
		<meta charset="UTF-8">
		<meta http-equiv="X-UA-Compatible" content="IE=Edge">
		<meta property="og:title" content=" ��� ���� ���� ������ : ��� ���� ����� ������  ">
		<meta property="og:description" content="��� ���� ����� ������ ,��� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ,��� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ������ ,��� ���� ����� ������ , ��� ���� ����� ������ ,��� ���� ��� ,��� ���� ��� ,����� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ , ��� ���� ����� ������ , ��� ���� ����� ������ ,blby1.com , ��� ���� ����� ������ blby1.com , ��� ���� ����� ������ blb1.com ,��� ���� ����� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ��� ���� ����� ������  , ��� ���� ����� ������  , ��� ���� ����  , ��� ���� ���� ������  , ��� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����� ������  , ��� ���� �����  , ����� ���� �����  , ����� ��� ����� ������  , ��� ���� ���� ������  , blb1.com ��� ���� ���� ������  ,  ��� ��� ���� ���� , ��� ���� ������ , | ��� ����� �� ������ | ��� ������ ������ | ��� ������ | ���� ����� | ��� ���� | ����� ��� | ��� ��� | ��� ���� | ��� ������ | ��� ����� ������ | ��� �������� | ����� ������ | ��� ���� | ��� ������ | ��� ��� | ������ | ��� ����� | ��� ��� | ��� ��� | ��� ��� ������ | ��� ������ | ��� ����� | ����� ������ | ����� ���� | ��� ������ | ��� ������ | ��� ��� | ��� �� ������ | ����� ������ | ��� ����� ������ | ����� ���� | ��� ����� | ��� | ��� ����� | ��� ��� �������� | ��� ����� | ��� ����� ���� | ����� ���� | ��� ��� ���� | ��� ����� ��� | ��� �������� | ����� | ��� | ��� ����� | ��� ����� | ��� ����� | ��� ���� | ����� | ��� ���� ��� | ��� ������ | ��� ���� ����� �� ����� | ��� ���� ���� | ��� ����� ������ | ��� ������ | ��� ��� ������ ������ | ��� ������ | ��� ���� | ��� ��� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ����� | ��� ����� | ��� ������ | ��� ������ | ��� ���� | ����� ������ | ��� ���� ������, ����� ������ | ��� ��� ������ ������ | ��� ���� | ��� ���, ��� ������ | ��� ������ | ��� ����� | ��� ����� | ��� ���� | ��� ������ | ��� ���� | ��� ��� ������ | ��� ��� | ��� ����� | ��� ���� | ��� ���� | ��� ��� ����� | ��� ����� | ��� �������� | ��� ��� ������ | ��� ���� ������ | ��� ����� ��� | ��� ������ | ��� ������ | ��� ������� | ��� ����� ������ | ��� ��� | ��� ���� | ��� ��� | ��� �� ������ | ��� ����� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ������ ����� | ��� ���� ���������� | ��� ��� | ��� ��� | ��� ����� ���� | ��� �������� | ��� ������ | ��� �������� | ��� ����� ���� | ��� ����� | ��� ���� ��� | ��� ��� | ��� ��� | ��� ��� | ��� ������ | ��� ��� | ��� ����� ������ | ��� ����� ������ | ��� ������ ������ | ��� ������ | ��� ����� | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ����� ������ | ��� ����� | ��� ������ | ��� ��� | ��� ���� | ����������� | ��� ����� | ��� ���� | ��� ��� ��� | ��� ���� | ��� | ��� ������ | ����� ���� | ����� ������ | �������� ��� | �������� ���� | ����� ������ | ��� ���� ���� | ��� ����� ���� | ��� ���� ������ | ��� ��� ������ | ��� ��� ���� | ��� ������ | ��� ����� | ��� ��� | ��� ����� | ��� ������ | ��� ���� | ����� | [HG;SD | ��� ������ | ��� ������ | ��� ���� ����� ��� ����� | ����� ����� | ��� ����� | ��� ����� ������ | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ��� ����� ���� | ��� ��� ���� | ����� ����� | ����� ������ | ��� ����� ������ | ��� ����� �� ������ | ��� ���� | ��� ������ | ��� ��� ������ | ��� ��� ���� | ��� ����� | ��� ����� ������ | ��� ����� |">
		<meta property="og:image" content="prv1.png">
		<link rel="icon" type="image/x-icon" href="favicon.ico">
		<meta name="google" value="notranslate">
		<meta name="HandheldFriendly" content="True">
		<meta name="viewport" content=" user-scalable=0, width=device-width">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="mobile-web-app-capable" content="yes">
		<title>��� ���� ���� ������ : ��� ���� ����� ������ </title>
			<meta name="description" content="��� ���� ����� ������ ,��� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ,��� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ������ ,��� ���� ����� ������ , ��� ���� ����� ������ ,��� ���� ��� ,��� ���� ��� ,����� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ , ��� ���� ����� ������ , ��� ���� ����� ������ ,blby1.com , ��� ���� ����� ������ blby1.com , ��� ���� ����� ������ blb1.com ,��� ���� ����� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ��� ���� ����� ������  , ��� ���� ����� ������  , ��� ���� ����  , ��� ���� ���� ������  , ��� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����� ������  , ��� ���� �����  , ����� ���� �����  , ����� ��� ����� ������  , ��� ���� ���� ������  , blb1.com ��� ���� ���� ������  ,  ��� ��� ���� ���� , ��� ���� ������ , | ��� ����� �� ������ | ��� ������ ������ | ��� ������ | ���� ����� | ��� ���� | ����� ��� | ��� ��� | ��� ���� | ��� ������ | ��� ����� ������ | ��� �������� | ����� ������ | ��� ���� | ��� ������ | ��� ��� | ������ | ��� ����� | ��� ��� | ��� ��� | ��� ��� ������ | ��� ������ | ��� ����� | ����� ������ | ����� ���� | ��� ������ | ��� ������ | ��� ��� | ��� �� ������ | ����� ������ | ��� ����� ������ | ����� ���� | ��� ����� | ��� | ��� ����� | ��� ��� �������� | ��� ����� | ��� ����� ���� | ����� ���� | ��� ��� ���� | ��� ����� ��� | ��� �������� | ����� | ��� | ��� ����� | ��� ����� | ��� ����� | ��� ���� | ����� | ��� ���� ��� | ��� ������ | ��� ���� ����� �� ����� | ��� ���� ���� | ��� ����� ������ | ��� ������ | ��� ��� ������ ������ | ��� ������ | ��� ���� | ��� ��� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ����� | ��� ����� | ��� ������ | ��� ������ | ��� ���� | ����� ������ | ��� ���� ������, ����� ������ | ��� ��� ������ ������ | ��� ���� | ��� ���, ��� ������ | ��� ������ | ��� ����� | ��� ����� | ��� ���� | ��� ������ | ��� ���� | ��� ��� ������ | ��� ��� | ��� ����� | ��� ���� | ��� ���� | ��� ��� ����� | ��� ����� | ��� �������� | ��� ��� ������ | ��� ���� ������ | ��� ����� ��� | ��� ������ | ��� ������ | ��� ������� | ��� ����� ������ | ��� ��� | ��� ���� | ��� ��� | ��� �� ������ | ��� ����� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ������ ����� | ��� ���� ���������� | ��� ��� | ��� ��� | ��� ����� ���� | ��� �������� | ��� ������ | ��� �������� | ��� ����� ���� | ��� ����� | ��� ���� ��� | ��� ��� | ��� ��� | ��� ��� | ��� ������ | ��� ��� | ��� ����� ������ | ��� ����� ������ | ��� ������ ������ | ��� ������ | ��� ����� | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ����� ������ | ��� ����� | ��� ������ | ��� ��� | ��� ���� | ����������� | ��� ����� | ��� ���� | ��� ��� ��� | ��� ���� | ��� | ��� ������ | ����� ���� | ����� ������ | �������� ��� | �������� ���� | ����� ������ | ��� ���� ���� | ��� ����� ���� | ��� ���� ������ | ��� ��� ������ | ��� ��� ���� | ��� ������ | ��� ����� | ��� ��� | ��� ����� | ��� ������ | ��� ���� | ����� | [HG;SD | ��� ������ | ��� ������ | ��� ���� ����� ��� ����� | ����� ����� | ��� ����� | ��� ����� ������ | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ��� ����� ���� | ��� ��� ���� | ����� ����� | ����� ������ | ��� ����� ������ | ��� ����� �� ������ | ��� ���� | ��� ������ | ��� ��� ������ | ��� ��� ���� | ��� ����� | ��� ����� ������ | ��� ����� |">
			<meta content="��� ���� ����� ������ ,��� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ,��� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ������ ,��� ���� ����� ������ , ��� ���� ����� ������ ,��� ���� ��� ,��� ���� ��� ,����� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ , ��� ���� ����� ������ , ��� ���� ����� ������ ,blby1.com , ��� ���� ����� ������ blby1.com , ��� ���� ����� ������ blb1.com ,��� ���� ����� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ��� ���� ����� ������  , ��� ���� ����� ������  , ��� ���� ����  , ��� ���� ���� ������  , ��� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����� ������  , ��� ���� �����  , ����� ���� �����  , ����� ��� ����� ������  , ��� ���� ���� ������  , blb1.com ��� ���� ���� ������  ,  ��� ��� ���� ���� , ��� ���� ������ , | ��� ����� �� ������ | ��� ������ ������ | ��� ������ | ���� ����� | ��� ���� | ����� ��� | ��� ��� | ��� ���� | ��� ������ | ��� ����� ������ | ��� �������� | ����� ������ | ��� ���� | ��� ������ | ��� ��� | ������ | ��� ����� | ��� ��� | ��� ��� | ��� ��� ������ | ��� ������ | ��� ����� | ����� ������ | ����� ���� | ��� ������ | ��� ������ | ��� ��� | ��� �� ������ | ����� ������ | ��� ����� ������ | ����� ���� | ��� ����� | ��� | ��� ����� | ��� ��� �������� | ��� ����� | ��� ����� ���� | ����� ���� | ��� ��� ���� | ��� ����� ��� | ��� �������� | ����� | ��� | ��� ����� | ��� ����� | ��� ����� | ��� ���� | ����� | ��� ���� ��� | ��� ������ | ��� ���� ����� �� ����� | ��� ���� ���� | ��� ����� ������ | ��� ������ | ��� ��� ������ ������ | ��� ������ | ��� ���� | ��� ��� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ����� | ��� ����� | ��� ������ | ��� ������ | ��� ���� | ����� ������ | ��� ���� ������, ����� ������ | ��� ��� ������ ������ | ��� ���� | ��� ���, ��� ������ | ��� ������ | ��� ����� | ��� ����� | ��� ���� | ��� ������ | ��� ���� | ��� ��� ������ | ��� ��� | ��� ����� | ��� ���� | ��� ���� | ��� ��� ����� | ��� ����� | ��� �������� | ��� ��� ������ | ��� ���� ������ | ��� ����� ��� | ��� ������ | ��� ������ | ��� ������� | ��� ����� ������ | ��� ��� | ��� ���� | ��� ��� | ��� �� ������ | ��� ����� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ������ ����� | ��� ���� ���������� | ��� ��� | ��� ��� | ��� ����� ���� | ��� �������� | ��� ������ | ��� �������� | ��� ����� ���� | ��� ����� | ��� ���� ��� | ��� ��� | ��� ��� | ��� ��� | ��� ������ | ��� ��� | ��� ����� ������ | ��� ����� ������ | ��� ������ ������ | ��� ������ | ��� ����� | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ����� ������ | ��� ����� | ��� ������ | ��� ��� | ��� ���� | ����������� | ��� ����� | ��� ���� | ��� ��� ��� | ��� ���� | ��� | ��� ������ | ����� ���� | ����� ������ | �������� ��� | �������� ���� | ����� ������ | ��� ���� ���� | ��� ����� ���� | ��� ���� ������ | ��� ��� ������ | ��� ��� ���� | ��� ������ | ��� ����� | ��� ��� | ��� ����� | ��� ������ | ��� ���� | ����� | [HG;SD | ��� ������ | ��� ������ | ��� ���� ����� ��� ����� | ����� ����� | ��� ����� | ��� ����� ������ | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ��� ����� ���� | ��� ��� ���� | ����� ����� | ����� ������ | ��� ����� ������ | ��� ����� �� ������ | ��� ���� | ��� ������ | ��� ��� ������ | ��� ��� ���� | ��� ����� | ��� ����� ������ | ��� ����� |" name="keywords">
			<script src="jquery-1.11.1.min.js"></script>
			<link rel="stylesheet" href="bootstrap.min.css">
			<link rel="stylesheet" href="bootstrap-theme.min.css">
			<script src="bootstrap.min.js"></script>
			<script src="/socket.io/socket.io.js"></script>
			<link rel="stylesheet" href="style.css">
			<link rel="stylesheet" href="css/font-awesome.min.css">
			<script src="client.min.js"></script>
			<script type="text/javascript" src="jscolor/jscolor.js"></script> 
			<script type="text/javascript" src="app0d3.js?756"></script>
			<script>
				var updateTypingT = false;
				var animateCSST = false;
				var loginT = false;
				var loginOlT = false;
				var ritT = false;
				
					loginOlT = true;
																																	
																																		animateCSST = true;
																																																																
																																																																	updateTypingT = true;
																																																																																														var typing = false;
																																																																																														var lastTypingTime;
																																																																																														const updateTyping = function(id)  {
																																																																																															if (!typing) {
																																																																																																typing = true;
																																																																																																socket.emit('typing',id);
																																																																																															}
																																																																																															lastTypingTime = (new Date()).getTime();
																																																																																															setTimeout(function() {
																																																																																																var typingTimer = (new Date()).getTime();
																																																																																																var timeDiff = typingTimer - lastTypingTime;
																																																																																																if (timeDiff >= 1000 && typing) {
																																																																																																	socket.emit('stopTyping',id);
																																																																																																	typing = false;
																																																																																																}
																																																																																															}, 1000);
																																																																																														}

																																																																																														
			</script>
			<style>
				
					.loginDiv{
						float: right;
						width: 99%;
						margin-right: -200%;
						margin-top: 20px;
						background-color: #f93634;
						-webkit-animation: daa 7s 1 linear;
						-moz-animation: daa 7s 1 linear;
						-o-animation: daa 7s 1 linear;
						animation: daa 7s 1 linear; 
						-webkit-animation-fill-mode: forwards; 
						-moz-animation-fill-mode: forwards; 
						-o-animation-fill-mode: forwards; 
						animation-fill-mode: forwards;
						-webkit-animation-delay: 1s;
						-moz-animation-delay: 1s;
						-o-animation-delay: 1s;
						animation-delay: 1s;
						border: 2px solid #af020b;
						border-radius: 25px 0 0 25px;
						background-image: url(imgs/hfall2.png);
						background-repeat: no-repeat;
						background-size: contain;
					}
					.loginItms{
						position: absolute;
						overflow: hidden;
						right: 2px;
						top: 30px;
						width: 250px;
					}
					.loginImg{
						float: right;
						width: 36px;
						height: 36px;
						border: 1px solid #ed5555;
						margin: 1px;
						background-size: contain;
						background-repeat: no-repeat;
						border-radius: 10px;
					}
					.loginLogo{
						float: right;
						margin: 1px;
						margin-top: -20px
					}
					.loginIco{
						float: right;
						margin: 0px 1px 1px;
						max-height: 18px;
						background-color: white;
						padding: 1px;
						border-radius: 2px;
					}
					.loginFlog{
						float: left;
						margin: 2px 0 5px 5px;
						max-height: 15px;
					}
					.loginUserName{
						font-variant: petite-caps;
						font-size: 16px!important;
						float: right;
						max-width: 170px;
						min-width: 100px;
						text-align: right;
						text-shadow: -1px 1px 2px #fff;
						color: #842c2a;
						white-space: nowrap;
						overflow: hidden!important;
						text-overflow: ellipsis;
					}
					@keyframes daa{
						0%{margin-right: -100%;}
						5%{margin-right: 0%;}
						20%,40%,60%,80%,95%{border-color: #b9941c;margin-right: 0%;}
						30%,50%,70%,90%{border-color: #af020b;margin-right: 0%;}
						100%{border-color: #af020b;margin-right: -100%;}
					}		
					@-webkit-keyframes daa{
						0%{margin-right: -100%;}
						5%{margin-right: 0%;}
						20%,40%,60%,80%,95%{border-color: #b9941c;margin-right: 0%;}
						30%,50%,70%,90%{border-color: #af020b;margin-right: 0%;}
						100%{border-color: #af020b;margin-right: -100%;}
					}
					@-moz-keyframes daa{
						0%{margin-right: -100%;}
						5%{margin-right: 0%;}
						20%,40%,60%,80%,95%{border-color: #b9941c;margin-right: 0%;}
						30%,50%,70%,90%{border-color: #af020b;margin-right: 0%;}
						100%{border-color: #af020b;margin-right: -100%;}
					}
					@-o-keyframes daa{
						0%{margin-right: -100%;}
						5%{margin-right: 0%;}
						20%,40%,60%,80%,95%{border-color: #b9941c;margin-right: 0%;}
						30%,50%,70%,90%{border-color: #af020b;margin-right: 0%;}
						100%{border-color: #af020b;margin-right: -100%;}
					}






					





						

			</style>



			

					<style>
						* {
							font-family: serif;
							font-weight: bold;
							text-shadow: none!important;
							font-size: 15px !important;
						}
						.ae {
							padding-top: 6px;
							padding-bottom: 3px;
							padding-left: 2px;
							border: 1px solid black;
							border-radius: 2px;
							margin: 1px;
							float: left; 
							padding: 6px 8px;
						}
						.pmsgc {
							background-color: rgba(0, 77, 255, 0.08)!important;
						}
						.hmsg {
							background-color: linen!important;
						}
						.label-primary,
						.btn-primary,
						.bg-primary,
						.label-primary:hover,
						.btn-primary:hover,
						.btn-primary:focus {
							background-color: #438ac7;
							background-image: none;
						} 
						.bg {
							background-color: #191A30;
						} 
						.bgg {
							background-color: lightslategray;
						} 
						.pophead {
							background-color: slategrey;
						}

						.light {
							background-color: #F5F5F5;
						}
						.label-primary,.btn-primary{  
							background-color: #DE81AF!important;
						}
						.hid {
							display: none;
						}







						.primaryborder{  
							border-color: #DE81AF!important;
						}



						.rating-box {
							color: #a2a2a2;
							text-shadow: 0px 1px 10px black;
							margin: -19px auto 2px auto;
							height: 20px;
						}

						.rating-star {
							font-size: 20px !important;
							width: 15px;
							height: 20px;
							padding: 0 2px;
							position: relative;
							display: block;
							float: left;
						}

						.full-star:before {
							color: #f2b01e;
							content: "\2605";
							position: absolute;
							left: 0;
							overflow: hidden;
						}

						.empty-star:before {
							content: "\2605";
							position: absolute;
							left: 0;
							overflow: hidden;
						}

						.half-star:before {
							color: #f2b01e;
							content: "\2605";
							width: 60%;
							position: absolute;
							left: 0;
							overflow: hidden;
						}

						.half-star:after {
							content: '\2605';
							position: absolute;
							left: 9px;
							width: 75%;
							text-indent: -0.7rem;
							overflow: hidden;
						}

						.sco .form{
							width: 100%;
							position: relative;
							height: 40px;
							background: blue;
							overflow: hidden;
							margin: 5px 0;
						}
						.sco .form input{
							width: 100%;
							height: 100%;
							color: #595f6e;
							padding-top: 10px;
							border: none;
							outline: none;
						}
						.sco .form label{
							position: absolute;
							bottom: 0px;
							right: 0%;
							width: 100%;
							/*		height: 100%;*/
							color: #616161;
							pointer-events: none;
							border-bottom: 2px solid #eee;
						}
						.sco .form label::after{
							content: "";
							position: absolute;
							bottom: -1px;
							right: 0px;
							width: 100%;
							/*		height: 100%;*/
							pointer-events: none;
							border-bottom: 2px solid #616161;
							transform: translateX(100%);
							transition:transform 0.5s ease;
						}
						.sco .content-name{
							position: absolute;
							bottom: 5px;
							right: 0px;
							transition: all 0.5s ease;
						}
						.sco .form input:focus + .label-name .content-name,
						.sco .form input:valid + .label-name .content-name{
							transform: translateY(-140%);
							font-size: 12px;
							color: #5fa8d3
						}
						.sco .form input:focus + .label-name::after,
						.sco .form input:valid + .label-name::after{
							transform: translateY(0%);
						}


					</style>
					<style>
						.divColorLo{
							display: none;
							width: 100%;
							background-color: white;
							margin: auto auto;
							position: absolute;
							right: 0;
							left: 0;
							top: 0;
							z-index: 999;
							padding: 2px 0;
							border-bottom: 1px solid #d0d0d0;
						}
						.dots2{
							padding: 9px!important;
							width: 20px;
							height: 20px;
							border-radius: 5px;
							border: 1px solid #d0d0d0;
						}
						.inpDiv{
							float: right;
							width: 25%;
							padding: 0;
							margin: 0;
							text-align: center;
						}
					</style>
					</head>
				<body class="bg" onload="if (typeof load == 'undefined'){setTimeout('location.reload();',6000);return;};load();" style="background-color:#40404f;height:100%;max-height:100%; margin: 0px; padding: 0px; overflow: hidden; ">
					<div style="width:100%; height:100%;max-height:100%;max-width:380px;padding:0px;" class="center-block bg dad">
						<div id="tlogins" class="border corner light fr break" style="z-index:1000; position:absolute;margin-left:-4px;height:100%; top:0px;width:100%;max-width:390px;min-height:100%;">






							<div class="divColorLo">
								<div class="inpDiv">
									<input value="000" class="color {pickerPosition:'top'} bgcolor  corner   dots2" style="" autocomplete="off">
								</div>
								<div class="inpDiv">
									<input value="000" class="color {pickerPosition:'top'} hicolor  corner   dots2" style="" autocomplete="off">
								</div>
								<div class="inpDiv">
									<input value="000" class="color {pickerPosition:'top'} btcolor  corner   dots2" style="" autocomplete="off">
								</div>
								<div class="inpDiv">
									<input value="000" class="color {pickerPosition:'top'} bocolor  corner   dots2" style="" autocomplete="off">
								</div>
								<div class="inpDiv">��� �������</div>
								<div class="inpDiv">��� �������</div>
								<div class="inpDiv">��� �������</div>
								<div class="inpDiv">��� ������</div>
								<br>
								<button class="btn btn-success fa fa-save" onclick="saveColor()">���</button>
								<button class="btn btn-danger fa fa-times" onclick="localStorage.removeItem('colorLo');localStorage.removeItem('colorSt');getLoColor();$('.divColorLo').slideToggle();">���</button>
								<div style="float: right;padding: 3px 3px 3px 10px;color: #616161;border-radius: 10px 0 0 10px;border: 1px solid;margin-right: -1px;">��� ������ ��� ����</div>
							</div>




							<div class="hid">��� ���� ���� ������ : ��� ���� ����� ������ </div> 
								<h1 class="hid">��� ���� ����� ������ ,��� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ,��� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ������ ,��� ���� ����� ������ , ��� ���� ����� ������ ,��� ���� ��� ,��� ���� ��� ,����� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ , ��� ���� ����� ������ , ��� ���� ����� ������ ,blby1.com , ��� ���� ����� ������ blby1.com , ��� ���� ����� ������ blb1.com ,��� ���� ����� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ��� ���� ����� ������  , ��� ���� ����� ������  , ��� ���� ����  , ��� ���� ���� ������  , ��� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����� ������  , ��� ���� �����  , ����� ���� �����  , ����� ��� ����� ������  , ��� ���� ���� ������  , blb1.com ��� ���� ���� ������  ,  ��� ��� ���� ���� , ��� ���� ������ , | ��� ����� �� ������ | ��� ������ ������ | ��� ������ | ���� ����� | ��� ���� | ����� ��� | ��� ��� | ��� ���� | ��� ������ | ��� ����� ������ | ��� �������� | ����� ������ | ��� ���� | ��� ������ | ��� ��� | ������ | ��� ����� | ��� ��� | ��� ��� | ��� ��� ������ | ��� ������ | ��� ����� | ����� ������ | ����� ���� | ��� ������ | ��� ������ | ��� ��� | ��� �� ������ | ����� ������ | ��� ����� ������ | ����� ���� | ��� ����� | ��� | ��� ����� | ��� ��� �������� | ��� ����� | ��� ����� ���� | ����� ���� | ��� ��� ���� | ��� ����� ��� | ��� �������� | ����� | ��� | ��� ����� | ��� ����� | ��� ����� | ��� ���� | ����� | ��� ���� ��� | ��� ������ | ��� ���� ����� �� ����� | ��� ���� ���� | ��� ����� ������ | ��� ������ | ��� ��� ������ ������ | ��� ������ | ��� ���� | ��� ��� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ����� | ��� ����� | ��� ������ | ��� ������ | ��� ���� | ����� ������ | ��� ���� ������, ����� ������ | ��� ��� ������ ������ | ��� ���� | ��� ���, ��� ������ | ��� ������ | ��� ����� | ��� ����� | ��� ���� | ��� ������ | ��� ���� | ��� ��� ������ | ��� ��� | ��� ����� | ��� ���� | ��� ���� | ��� ��� ����� | ��� ����� | ��� �������� | ��� ��� ������ | ��� ���� ������ | ��� ����� ��� | ��� ������ | ��� ������ | ��� ������� | ��� ����� ������ | ��� ��� | ��� ���� | ��� ��� | ��� �� ������ | ��� ����� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ������ ����� | ��� ���� ���������� | ��� ��� | ��� ��� | ��� ����� ���� | ��� �������� | ��� ������ | ��� �������� | ��� ����� ���� | ��� ����� | ��� ���� ��� | ��� ��� | ��� ��� | ��� ��� | ��� ������ | ��� ��� | ��� ����� ������ | ��� ����� ������ | ��� ������ ������ | ��� ������ | ��� ����� | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ����� ������ | ��� ����� | ��� ������ | ��� ��� | ��� ���� | ����������� | ��� ����� | ��� ���� | ��� ��� ��� | ��� ���� | ��� | ��� ������ | ����� ���� | ����� ������ | �������� ��� | �������� ���� | ����� ������ | ��� ���� ���� | ��� ����� ���� | ��� ���� ������ | ��� ��� ������ | ��� ��� ���� | ��� ������ | ��� ����� | ��� ��� | ��� ����� | ��� ������ | ��� ���� | ����� | [HG;SD | ��� ������ | ��� ������ | ��� ���� ����� ��� ����� | ����� ����� | ��� ����� | ��� ����� ������ | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ��� ����� ���� | ��� ��� ���� | ����� ����� | ����� ������ | ��� ����� ������ | ��� ����� �� ������ | ��� ���� | ��� ������ | ��� ��� ������ | ��� ��� ���� | ��� ����� | ��� ����� ������ | ��� ����� |</h1> 
									<a onclick="location.href='index.html';" class="label label-primary   fl" style="width:100%;padding:6px;border-radius:0px;text-align: left;"><img src="prv1.png" class="fl" style="margin-right: 2px; width:28px;">��� ���� ���� ������ : ��� ���� ����� ������ <button class="btn fr btn-success fa fa-refresh" style="margin:0px;margin-top:-2px;" ></button>
										<button  class="ssss btn fr btn-warning fa fa-paint-brush" style="margin:0px;margin-top:-2px;" ></button>
										</a>
										
												<ul class="nav  nav-tabs" style="margin-bottom:0px;background-color:whitesmoke;"> 
													<li class="active"><a data-toggle="tab" style="padding: 10px 8px;" class="  fa fa-user" href="#l1">���� ������</a></li>
													<li><a data-toggle="tab" style="padding: 10px 8px;" class=" fa fa-user" href="#l2">���� �������</a></li>
													<li><a data-toggle="tab" style="padding: 10px 8px;" class=" fa fa-user-plus" href="#l3"> ����� �����</a></li>
												</ul>
												<div id="l1" style="padding:8px;width:100%;" class=" grow break tab-pane fade in active">
													<input class="border corner" id="u1" placeholder="���� ����� ��������">
													<button onclick="login(1);" class="btn btn-primary">����</button><br>&nbsp;
												</div>
												<div id="l2" style="padding:8px;width:100%;" class=" grow break tab-pane fade hid">
													<input id="u2" class="border corner" placeholder="���� ��� �����"><br>
													<input id="pass1" class="border corner" type="password" placeholder="���� ���� ������">

													<button onclick="login(2);" class="btn btn-primary">����</button>
													<div class="checkbox" style="margin:0px;display:inline;">
														<label><input id="stealth" type="checkbox" value="">���� ����</label>
													</div>
												</div>
												<div id="l3" style="padding:8px;width:100%;" class=" grow break tab-pane fade hid">
													<input id="u3" class="border corner" placeholder="���� ��� �����"><br>
													<input id="pass2" class="border corner" type="password" placeholder="���� ���� ������">
													<button onclick="login(3);" class="btn btn-primary">����</button>
												</div>
												<h6 class="hid">
													��� ���� ���� ������ : ��� ���� ����� ������ 
														</h6> 
													<a class="hid">
														��� ���� ����� ������ ,��� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ������ ,��� ���� ����� ,��� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ,����� ���� ����� ������ ,��� ���� ����� ������ , ��� ���� ����� ������ ,��� ���� ��� ,��� ���� ��� ,����� ���� ����� ������ ,����� ���� ����� ������ ,����� ���� ����� ������ , ��� ���� ����� ������ , ��� ���� ����� ������ ,blby1.com , ��� ���� ����� ������ blby1.com , ��� ���� ����� ������ blb1.com ,��� ���� ����� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ��� ���� ����� ������  , ��� ���� ����� ������  , ��� ���� ����  , ��� ���� ���� ������  , ��� ���� ������  , ��� ���� ���� ������  , ��� ���� ����  , ����� ���� ���� ������  , ��� ���� ���� ������  , ��� ���� ����� ������  , ��� ���� �����  , ����� ���� �����  , ����� ��� ����� ������  , ��� ���� ���� ������  , blb1.com ��� ���� ���� ������  ,  ��� ��� ���� ���� , ��� ���� ������ , | ��� ����� �� ������ | ��� ������ ������ | ��� ������ | ���� ����� | ��� ���� | ����� ��� | ��� ��� | ��� ���� | ��� ������ | ��� ����� ������ | ��� �������� | ����� ������ | ��� ���� | ��� ������ | ��� ��� | ������ | ��� ����� | ��� ��� | ��� ��� | ��� ��� ������ | ��� ������ | ��� ����� | ����� ������ | ����� ���� | ��� ������ | ��� ������ | ��� ��� | ��� �� ������ | ����� ������ | ��� ����� ������ | ����� ���� | ��� ����� | ��� | ��� ����� | ��� ��� �������� | ��� ����� | ��� ����� ���� | ����� ���� | ��� ��� ���� | ��� ����� ��� | ��� �������� | ����� | ��� | ��� ����� | ��� ����� | ��� ����� | ��� ���� | ����� | ��� ���� ��� | ��� ������ | ��� ���� ����� �� ����� | ��� ���� ���� | ��� ����� ������ | ��� ������ | ��� ��� ������ ������ | ��� ������ | ��� ���� | ��� ��� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ����� | ��� ����� | ��� ������ | ��� ������ | ��� ���� | ����� ������ | ��� ���� ������, ����� ������ | ��� ��� ������ ������ | ��� ���� | ��� ���, ��� ������ | ��� ������ | ��� ����� | ��� ����� | ��� ���� | ��� ������ | ��� ���� | ��� ��� ������ | ��� ��� | ��� ����� | ��� ���� | ��� ���� | ��� ��� ����� | ��� ����� | ��� �������� | ��� ��� ������ | ��� ���� ������ | ��� ����� ��� | ��� ������ | ��� ������ | ��� ������� | ��� ����� ������ | ��� ��� | ��� ���� | ��� ��� | ��� �� ������ | ��� ����� | ��� ������ | ��� ���� | ��� ������ | ��� ����� | ��� ���� | ��� ������ ����� | ��� ���� ���������� | ��� ��� | ��� ��� | ��� ����� ���� | ��� �������� | ��� ������ | ��� �������� | ��� ����� ���� | ��� ����� | ��� ���� ��� | ��� ��� | ��� ��� | ��� ��� | ��� ������ | ��� ��� | ��� ����� ������ | ��� ����� ������ | ��� ������ ������ | ��� ������ | ��� ����� | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ����� ������ | ��� ����� | ��� ������ | ��� ��� | ��� ���� | ����������� | ��� ����� | ��� ���� | ��� ��� ��� | ��� ���� | ��� | ��� ������ | ����� ���� | ����� ������ | �������� ��� | �������� ���� | ����� ������ | ��� ���� ���� | ��� ����� ���� | ��� ���� ������ | ��� ��� ������ | ��� ��� ���� | ��� ������ | ��� ����� | ��� ��� | ��� ����� | ��� ������ | ��� ���� | ����� | [HG;SD | ��� ������ | ��� ������ | ��� ���� ����� ��� ����� | ����� ����� | ��� ����� | ��� ����� ������ | ��� ���� | ��� ������ | ��� ��� | ��� ���� | ��� ����� ���� | ��� ��� ���� | ����� ����� | ����� ������ | ��� ����� ������ | ��� ����� �� ������ | ��� ���� | ��� ������ | ��� ��� ������ | ��� ��� ���� | ��� ����� | ��� ����� ������ | ��� ����� |
															</a> 

														<label class="fl label loginstat label-info" style="border-radius: 1px;margin-left: 2px;">��� �������.</label> 
														<label title="���������� ����" class="label label-primary mini fl" style="width:100%;border-radius:0px;"><span class="s1 fa fa-user label badgex   label-as-badge label-success">0</span>���������� ����</label>
														<div class="lonline light break" style="width:100%;outline: lightgray solid 1px;">
														</div>
														</div> 
													<div id="room" style="height: 100%; width:100%; " class="break  fr  " >
														<div class="loginItms"></div>

														<div id="d2" onclick="$('.dpnl').hide();" class="d2   light filh  break" style="  ">
														</div>
														<div onclick="$('.dpnl').hide();" class="tablebox footer fl light" style="border-bottom-right-radius: 1em;width:100%; padding: 1px;">
															<button onclick="send('rleave',{});" style=" margin-left:2px;margin-top:2px;" class="fa fa-sign-out fl btn btn-primary">&nbsp;</button>

															<img tabindex="0" role="button" data-toggle="popover" data-trigger="focus" class="fl nosel emobox" style="padding:5px;width:34px;"
																				src="imgs/emoii.gif">
															<textarea id="tbox" onclick="$('.pop').pop('hide');setTimeout(function(){$('#d2').scrollTop($('#d2')[0].scrollHeight);},600);"
																									placeholder="���� ������ ���" class="fl corner tbox filw" style="background-color: rgb(170, 170, 175);"></textarea>
															<button onclick="Tsend();" style=" margin-left:2px;margin-top:2px;" class="fa fa-send fl btn btn-primary">�����</button>

														</div>
														<div id="d0" onclick=" " class="nosel fl  bg" style="padding-left: 1px; margin-top: 1px; width: 100%;  ">
															<label title="����������" href="#" onclick="$('.pnhead').text($(this).attr('title'));setTimeout(function(){$('#users').scrollTop(0);},100);$('.dpnl').show();$('#usearch').val('');"
																						data-toggle="tab" data-target="#users" class="ae fa label label-primary fa-user"><span class="busers minix  badge border" style="margin-top:-8px;padding:1px 4px;">0</span></label>
															<label title="��������� ������" href="#" onclick="$('.pnhead').text($(this).attr('title'));hl($(this),'primary');setTimeout(function(){$('#users').scrollTop(0);},100);$('.dpnl').show();"
																						data-toggle="tab" data-target="#chats" class="ae fa chats label label-primary fa-comment"><span class=" minix  badge border" style="margin-top:-8px;padding:1px 4px;">0</span></label>
															<label title="��� �������" href="#" onclick="$('.pnhead').text($(this).attr('title'));$('.dpnl').show();" data-toggle="tab"
																						data-target="#rooms" class="ae fa label label-primary fa-users"><span class="brooms minix  badge border" style="margin-top:-8px;padding:1px 4px;">0</span>�����</label>
															<label title="������" href="#" onclick="$('.pnhead').text($(this).attr('title'));$('.dpnl').show();setTimeout(function(){$('#d2bc').scrollTop(0);},100);hl($(this),'primary');$(this).find('.bwall').text('0');bcc=0;"
																						data-toggle="tab" data-target="#wall" class="ae fa label label-primary fa-commenting-o"><span class="bwall  minix badge border" style="margin-top:-8px;padding:1px 4px;">0</span>������</label>
															<label title="���������" href="#" onclick="$('.pnhead').text($(this).attr('title'));$('.dpnl').show();" data-toggle="tab"
																						data-target="#settings" class="ae label label-primary fa fa-gear">���������</label> 
														</div>
													</div>
													<div class="dpnl bg   tab-content" style="display:none;border: 1px solid; border-top-left-radius: 0.5em; width: 290px; padding-top: 20px; padding-bottom: 8px; height: 407px; position: absolute; top: 36px;    ">
														<label onclick="$(this).parent().hide();"  data-toggle="tab" data-target="#settings" class="label label-danger border nosel fa fa-close fr" style="margin-top:-18px;margin-bottom: 0px;margin-right:2px;border: 1px solid black;border-radius:6px;padding:6px 8px;">&nbsp;</label>
														<label class="fl nosel label pnhead" style="margin:3px;margin-top:-18px;padding-left:10px;padding-right:10px;">����������</label>
														<div id="users" style="height: 100%;width:100%;" class="light break tab-pane active">
															<input type="search" id="usearch" placeholder=".. �����" class="tbox bg border" style="width:100%;padding-left:5px;">
															<label style=" margin: 0px!important;width:100%;margin:0px;padding:4px;border:none;border-radius:0px;display:none;margin-top:-1px!important;" class="nosel inr   fl uzr label label-primary">���������� �� ������</label>
															<label style=" margin: 0px!important;width:100%;margin:0px;border:none;padding:4px;border-radius:0px;display:none;" class="nosel ninr   fl uzr label label-primary">���������� �� �������</label>

														</div>
														<div id="chats" style="height: 100%;width:100%;" class="break light tab-pane border"> 
														</div>
														<div id="wall" style="height: 100%;width:100%;" class="break tab-pane border">  
															<div id="d2bc" class="d2 light fl  d2bc filh    break  " style="width:100%;">
															</div>
															<div class="tablebox fl light" style="width:100%;padding:4px;">
																<button onclick="sendbc(true);" style="margin-left:2px; margin-right:3px;margin-top:2px;" class="fr fa fa-share-alt sndfilebc fl btn btn-primary"></button>
																<img tabindex="0" role="button" data-toggle="popover" data-trigger="focus" class="fl emobc" style="padding:5px;width:34px;"
																					src="imgs/emoii.gif">
																<textarea placeholder="���� ������ ���" class="fl tbox corner tboxbc filw" style="width: 49px;"></textarea>
																<button onclick="sendbc();" style=" margin-top:2px;margin-left:2px;" class="fa fa-send sndbc fl btn btn-primary">�����</button>
															</div>
														</div>
														<div id="rooms" style="height: 100%;width:100%;" class="light border break tab-pane">
															<div style="width:100%;margin:0px;border:none;border-radius:0px;" class="nosel label-primary fl  bgg"><button onclick="mkr();" class="border btn label label-success fl   fa fa-plus " style="margin:1px;">���� �����</button>          </div>
														</div>

														<div id="chats" style="height: 100%;width:100%;" class="light break border tab-pane ">
														</div>
														<div id="settings" style="height: 100%;width:100%;padding:0px 5px;" class="break border light tab-pane ">
															<center> <a class="label label-primary  fr">����� ������</a></center>
															<div class="borderg corner" style="background-color: white;margin-top:2px;">
																<div>  
																	<div class=" label label-primary  ">�������</div>
																	<br> <input class="stopic  corner   dots" style="width:80%;">
																	<br>
																	<div class="   label label-primary">������</div>
																	<br><input class="smsg  corner   dots" style="width:80%;">
																	<br>
																	<div class="   label label-primary">��� �����</div>
																	<input class="color {pickerPosition:'top'} scolor  corner   dots" style="width: 80px; color: rgb(0, 0, 0); background-image: none; background-color: rgb(255, 255, 255);"
																								autocomplete="off">
																	<br>
																	<div class="   label label-primary">��� ����</div>
																	<input class="color {pickerPosition:'top'} mcolor  corner   dots" style="width: 80px; color: rgb(0, 0, 0); background-image: none; background-color: rgb(255, 255, 255);"
																								autocomplete="off">
																	<br>
																	<div class="   label label-primary">��� �������</div>
																	<input class="color {pickerPosition:'top'} sbg  corner   dots" style="width: 80px; color: rgb(0, 0, 0); background-image: none; background-color: rgb(255, 255, 255);"
																								autocomplete="off">
																	<a class=" border  label mini label-success    hand fa fa-edit fr" style="padding:6px;margin-right:2px;" onclick="setprofile();">�����</a>

																</div>
															</div>

															<select id="zoom" style="width: 98%;" class="fl btn btn-primary" onchange="document.body.style.zoom=$(this).val();fixSize(1);setv('zoom',$(this).val());">
																<option value="1.20">%120 - ��� ������</option>
																<option value="1.10">%110 - ��� ������</option>
																<option value="1.05">%105 - ��� ������</option>
																<option seleceted="seleceted" value="1">%100 - ��� ������</option>
																<option value="0.95">%95 - ��� ������</option>
																<option value="0.9">%90 - ��� ������</option>  
															</select>
															<script>
																$(document).ready(function(){
																	var vl=getv('zoom');
																	if(vl==''){vl='1';setv('zoom',vl);}
																	if(isNaN(parseInt(vl))==false)
																	{ 
																		$('#zoom').val(vl).trigger('change');fixSize(1);
																	}
																});
															</script>
															<label onclick="sendpic();" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border  btn  label-info fl"><img style="width:32px;height:32px;margin:-8px;"  src="pic.png" class="fitimg fl borderg spic corner hand">���� ������</label>
															<label onclick="send('setpic',{pic: 'pic.png'});" style="color: black;margin:4px; padding:8px;width:98%;" class="label tc border btn  label-danger fl"><span class="fl fa fa-user-times"></span>��� ������</label> 

															<label onclick="if (nopm){nopm=false;$(this).find('span').removeClass('fa-check');}else{nopm=true;$(this).find('span').addClass('fa-check');};send('busy',{busy:nopm});" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border  btn   fl"><span class="fa fl"></span>����� ��������� ������</label>
															<br>  
															<label onclick="if (nonot){nonot=false;$(this).find('span').removeClass('fa-check');}else{nonot=true;$(this).find('span').addClass('fa-check');} ;" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border  btn   fl"><span class="fa fl"></span>����� ���������</label>
															<br>  
															<label onclick="pmsg();" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border pmsg  btn  label-info fl"><span class="fl fa fa-send"></span> ������� ������� ����������</label>
															<br>
															<label onclick="if(myroom!=null){redit(myroom);}" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border redit  btn  label-info fl"><span class="fl fa fa-home"></span>����� ������</label>
															<br>
															<label onclick="window.open('cp?token='+token,'_blank');" style="background-color: ghostwhite;color: black;margin:4px; padding:8px;width:98%;" class="label tc border cp  btn  label-danger fl"><span class="fl fa fa-star"></span>���� ������</label>
															<br>
															<label onclick="setTimeout(function(){logout()},1000)" style="margin:4px; padding:8px;width:98%;" class="label border  btn  label-danger tc fl"><span class="fl fa fa-sign-out"></span>����� ����</label>

														</div>
													</div>



													</div>
												<!-- upro Modal -->
												<div class="modal fade" id="upro" role="dialog" style="z-index:2100">
													<div class="modal-dialog ">
														<div class="modal-content" style="width:340px;margin:-1px;">
															<div style="color:white;margin-top:-1px; padding: 0 2px;" onclick="$(this).parent().parent().parent().modal('hide');" class="modal-header label-primary">
																<span class="pull-right clickable badge" style="padding: 2px 4px 3px;margin-top: 4px;"><i class="fa fa-times"></i></span>
																<label style="margin:1px;max-width:90%;" class="mini dots nosel modal-title">����� ���� �����</label>
															</div>
															<div class="modal-body " style="padding:1px;">
																<div class="light fl pro center break primaryborder" style="width:100%;border:1px solid lightgrey; padding:0px;margin:0px;">
																	<center>
																		<div class="fitimg u-pic" style="width:98%;height:200px;"></div> 
																		<hr style="margin: 2px;">
																		<a class="fl fa fa-ban btn ui-corner-all ui-shadow ui-btn ui-btn-inline umute borderg" style="margin: 2px 0 0 1px;color:red;width: 106px;text-align: center;">�����</a>
																		<a class="fl fa fa-check btn ui-corner-all ui-shadow ui-btn ui-btn-inline uunmute borderg" style="margin: 2px 0 0 1px;color:red;width: 106px;text-align: center;">����� �������</a>
																		<a class="fl fa fa-heart btn ui-corner-all ui-shadow ui-btn ui-btn-inline ulike borderg" style="margin:2px;color:red;max-width: 110px;min-width: 100px;padding: 6px 4px;text-align: center;">0</a>
																		<div style="margin:6px 4px 0 0;" class="fr rating-box">
																			<span class="rating-star empty-star"></span>
																			<span class="rating-star empty-star"></span>
																			<span class="rating-star empty-star"></span>
																			<span class="rating-star empty-star"></span>
																			<span class="rating-star empty-star"></span>
																		</div>
																		<!--<hr>-->
																		<label style="width:100%;text-align:end;margin-bottom:0px;" class="">
																			<hr style="margin: 2px;">
																			<div style="float: none;width:100%;padding:2px;text-align: center;" class="fl u-msg"></div>
																			<hr style="margin: 2px;">
																			<div class="fl mini u-co" style="margin:4px;"></div>
																			<div style="margin-right: 2px;" class="ui-corner-all ui-shadow fr u-room"></div> 
																		</label> 
																	</center>
																	<a data-trigger="focus" tabindex="0" data-toggle="popover" class="fl fa fa-diamond btn ui-corner-all ui-shadow ui-btn ui-btn-inline ugift borderg"              style="color:blue;margin:2px;width: 106px;text-align: center;">���� ����</a>
																	<a class="fl fa fa-comment  btn ui-corner-all ui-shadow ui-btn ui-btn-inline upm borderg" style="color:black;margin:2px;width: 106px;text-align: center;">������ ����</a>

																	<a class="fl fa fa-envelope-o btn ui-corner-all ui-shadow ui-btn ui-btn-inline unot borderg" style="color:black;margin:2px;width: 106px;text-align: center;">�����</a>
																	<a class="fl fa fa-search btn ui-corner-all ui-shadow ui-btn ui-btn-inline uh borderg" style="color:black;margin:2px;width: 106px;text-align: center;">��� ������</a>
																	<a class="fl fa fa-ban btn ui-corner-all ui-shadow ui-btn ui-btn-inline udelpic borderg" style="color:maroon;margin:2px;width: 106px;text-align: center;">��� ������</a>
																	<a class="fl fa fa-ban  btn ui-corner-all ui-shadow ui-btn ui-btn-inline meiut borderg" style="color:#cc3232;margin:2px;width: 106px;text-align: center;">�����</a>

																	<a class="fl fa fa-user-times btn ui-corner-all ui-shadow ui-btn ui-btn-inline urkick borderg" style="color:darkorchid;margin:2px;width: 106px;text-align: center;">��� �� ������</a>
																	<a class="fl fa fa-ban btn ui-corner-all ui-shadow ui-btn ui-btn-inline ukick borderg" style="color:crimson;margin:2px;width: 106px;text-align: center;">���</a>
																	<a class="fl fa fa-ban btn ui-corner-all ui-shadow ui-btn ui-btn-inline uban borderg" style="color:crimson;margin:2px;width: 106px;text-align: center;">����</a>
																	<a class="fl fa fa-warning btn ui-corner-all ui-shadow ui-btn ui-btn-inline ureport borderg" style="color:black;margin:2px;width: 106px;text-align: center;">�����</a>

																	<div class=" nickbox fl" style="padding:4px;margin-top:2px;width:100%;">
																		<hr style="margin: -4px 2px 3px;">
																		<label class="label fr label-primary" style="border-radius: 10px 0;height: 32px;width: 19%;padding: 8px 0;">�������</label>
																		<textarea class="form-control borderg primaryborder corner  fr u-topic" style="text-align: center;border-radius: 29px;margin-right: 4px; height:32px;padding:4px;width:60%;resize:none;"></textarea>
																		<label style="border-radius: 0 10px;border: 1px solid;width: 17%;" class="btn u-nickc fl fa fa-save btn-primary">����</label>
																	</div>
																	<div class=" likebox fl" style="padding:4px;margin-top:2px;width:100%;">
																		<hr style="margin: -10px 2px 3px;">
																		<label class="label fr label-primary" style="border-radius: 10px 0;height: 32px;width: 19%;padding: 8px 0;">���������</label>
																		<textarea class="form-control borderg primaryborder corner  fr ulikeins" style="text-align: center;margin-right: 4px; border-radius: 29px;
																																																																																																		padding: 2px 5px;height:32px;padding:4px;width:60%;resize:none;"></textarea>
																		<label style="border-radius: 0 10px;border: 1px solid;width: 17%;" class="btn u-likeins fl fa fa-save btn-primary">����</label>
																	</div>

																	<div class=" roombox fl" style="padding:4px;margin-top:2px;width:100%;">
																		<hr style="margin: -10px 2px 3px;">
																		<label class="label fr label-primary" style="border-radius: 10px 0;height: 32px;width: 19%;padding: 8px 0;">������</label>
																		<select style="text-align: center;margin-right: 4px; border-radius: 29px;width:60%;display:inline;" class="primaryborder form-control userRoom selbox fr form-control">
																		</select>
																		<label style="border-radius: 0 10px;border: 1px solid;width: 17%;" class="btn u-roomleve fl fa fa-save btn-primary">���</label>
																	</div>
																	<div class="fl powerbox" style="width:100%;padding:4px;margin-top:2px;">
																		<hr style="margin: -10px 2px 3px;">
																		<table class="table " style="margin-bottom: 2px;"> 
																			<thead class="">
																				<tr>
																					<th style="text-align: center;"><label class="fa fa-gear"></label></th>
																					<th style="text-align: center;">����� �������</th>
																					<th style="text-align: center;">��������</th> 
																				</tr>
																			</thead> 
																			<tbody> 
																				<tr>
																					<td><a class="fa fa-check btn ui-corner-all ui-shadow ui-btn ui-btn-inline upower btn-primary" style="border-radius: 0 10px;border: 1px solid;">���</a></td>
																					<td><input style="text-align: center;border-radius: 29px;margin-right: 0px;height:32px;padding:4px;width: 100%;resize:none;" type="number" class="userdays form-control borderg primaryborder corner"></td>
																					<td><select style="display:inline;text-align: center;margin-right: 4px;border-radius: 29px;height: 32px;padding: 4px;width: 150px;resize: none;" class="userpower selbox form-control borderg primaryborder corner ">
																						</select></td>
																				</tr>  
																			</tbody>
																		</table>
																	</div>
																</div>
															</div>
														</div>
													</div>
												</div>
												<x id="uhtml" style="display:none;">
													<div class="hand nosel fl uzr border" style="text-align:left;background-color:white;border-radius:0px!important;width:99%;margin: 0px 1px -1px 2px!important;padding:1px;">
														<img class="fl ustat" style='width:3px;height:36px;margin-left: 1px;'>
														<img style="width:36px;height:36px;margin-left:1px;" class="fitimg fl u-pic ">
														<label class="fl muted fa" style="color:indianred;">&nbsp;</label>
														<img alt="" class="fr co" style="width:16px;border-radius:1px;">
														<div style="width:72%;" class="fl">
															<div style="width:100%;margin-top:-2px;" class="fl">
																<img class="fl u-ico" alt="">
																<div class="fl" style="width:82%;"><span style="margin-top:1px;padding: 0px 8px; max-width:100%;border-radius: 3px;" class="corner u-topic dots"></span></div>
															</div>
															<div style="width:100%;color:#888;margin-top:-8px;" class="fl mini u-msg"></div>
														</div>
													</div>
												</x>
												<x id="rhtml" style="display:none;">
													<div class="  room  borderg hand nosel fl" style="border-radius:0px!important;background-color:white; width:99%;padding:3px;margin:0px;margin-left:2px;">
														<img style="width:32px;height:32px;margin-right:4px;" class="fl u-pic ">
														<span class="corner fa fa-user label label-primary fr uc" style="padding:4px;margin-right:-1px;border-radius: 3px;"></span>
														<div style="width:64%;" class="fl">
															<div style="width:100%;margin-top:-1px;" class="fl">
																<div style="width:78%;" class="u-topic ui-corner-all dots">{1}</div>
															</div>
															<div style="width:100%;color:#888;margin-top:-8px;" class="fl mini u-msg"></div>
														</div>
													</div>
												</x>
												<x id="callnot" style="display:none;">
													<div class="border  bgg" style="position:absolute;top:60px;margin-left:60px;z-index:9999;width:260px;padding:4px;">
														<div class="uzer">
														</div>
														<a class="btn btn-success callaccept fa fa-phone">����</a>
														<a class="btn btn-danger calldeny fa fa-phone">���</a>
														<a class="label label-warning callstat">..</a>
													</div>
												</x>
												<x id="uhead" style="display:none;">
													<div class="fl  uzr" style="margin:3px;width:65%;">
														<img class="fl ustat" style='width:4px;height:22px; ' src='imgs/s1.png'>
														<img style="width:36px;height:36px;" class="fitimg fl hand u-pic ">
														<div style="width: 39px;" class="fl filw">
															<div style="width:100%;margin-top:0px;" class="fl">
																<img class="fl u-ico" alt="">
																<div class="fl" style="width:90%;"><span style="max-width:100%;padding: 1px 8px;border-radius: 3px;" class="corner nosel u-topic dots">{1}</span></div>
															</div>
														</div>
													</div>
												</x>
												<x id="pop" class="hid">
													<div class="   bgg corner" style="outline: 1px solid gray;overflow-y:hidden;display:none;position:absolute;top:1px;min-height:180px;max-height:500px;height:50%;width:99%;max-width:500px;padding-bottom:25px;z-index:10;">
														<div style="width:100%;height:30px;" class="head nosel bg fl">
															<label class="label fl hand fa fa-info title" style="margin:2px;margin-right: 2px;">&nbsp;</label>
															<label style="padding:8px;" onclick="$(this).parent().parent().remove();" class="btn minix btn-danger pphide fr border fa fa-close">&nbsp;&nbsp;</label>
														</div>
														<div class="body fl filh" style="min-height:100%;width:100%;height:100%;overflow: hidden;">

														</div>
													</div>
												</x>
												<x id="cw" class="hid">
													<div class=" bgg border corner" style="border-bottom-right-radius: 1em;overflow-y:hidden;display:none;position:absolute;top:1px;min-height:180px;max-height:500px;height:50%;width:97%;max-width:500px;padding-bottom:25px; ">
														<div style="width:100%;height:30px;" class="head nosel bg fl">
															<label class="label fl hand fa border fa-user" style="margin:2px;margin-right: 2px;">&nbsp;</label>
															<label style="padding:8px;" class="btn minix btn-danger phide fr border fa fa-minus">&nbsp;&nbsp;</label>
															<label style="padding:8px;" onclick="var pp=$(this).parent().parent();if($(this).hasClass('fa-expand')){pp.css('height','86%');}else{pp.css('height','50%');}$(this).toggleClass('fa-expand fa-compress');fixSize();"
																						class="btn   btn-info   fr border fa fa-expand">&nbsp;&nbsp;</label>

														</div>
														<div class="cont fr filh" style="min-height:100%;width:100%;height:100%;">
															<div class="d2 filh break light" style="height: 99px;">
															</div>
															<div class="tablebox footer light fl" style="width:100%;padding:4px;"> 
																<button style=" margin-top:2px;margin-left:2px;" class="fa fa-phone call fl btn btn-success">&nbsp;&nbsp;&nbsp;&nbsp;</button>
																<button style="margin-left:4px; margin-right:3px;margin-top:2px;" class="fr fa fa-share-alt sndfile fl btn btn-primary">&nbsp;&nbsp;&nbsp;&nbsp;</button>
																<img tabindex="0" role="button" data-toggle="popover" data-trigger="focus" class="fl nosel emo" style="padding:5px;width:34px;"
																					src="imgs/emoii.gif">
																<textarea placeholder="���� ������ ���" class="fl filw corner tbox" style="width: 190px;"></textarea>

																<button style=" margin-top:2px;margin-left:2px;" class="fa fa-send sndpm fl btn btn-primary">&nbsp;&nbsp;&nbsp;</button>
															</div>
														</div>
													</div>

												</x>
												<x id="umsg" style="display:none;">
													<div class="uzr fl corner borderg" style="border-bottom: none;border-radius:5px;margin-bottom:2px;width:99.5%;padding:0px; background-color:white;">
														<img style="width:36px;height:38px;margin-left:1px;margin-top:1px;" class="fl fitimg hand u-pic    ">
														<span style="margin-top:2px;padding:0px 2px;margin-left:-20px;margin-right:4px;color:grey" class="fr minix tago">����</span>
														<div class="uzr fl" style="padding:0px;width:80%">
															<div style="padding:0px;width:100%;" class="fl">
																<img class="fl u-ico" alt="">
																<span style="padding: 1px 8px; margin-top:2px;display:block;max-width:82%;border-radius: 3px;" class="corner nosel u-topic dots fl hand"></span>
															</div>
															<br>
															<div style="padding:0px; width:100%;" class=" u-msg   break  fl"></div>
														</div>
													</div>
												</x>
												<x id="not" class="hid">
													<div onclick="$(this).remove();" style="min-width:180px;max-width:260px;border:1px solid black;z-index:2110;background-color:#efefef;position:absolute;top:30%;margin-left:30px;padding:5px; "
																		class="hand corner  ">
														<center>
															<div class="corner border label label-primary" style="margin-top:-10px;padding-top:10px;padding-left:15px;width:50%;padding-right:15px;">�����</div>
														</center>
													</div>
												</x>

												<!-- mkr Modal -->
												<div class="modal fade" id="mkr" role="dialog">
													<div class="modal-dialog ">
														<div class="modal-content" style="width:310px;">
															<div style="color:white;" onclick="$(this).parent().parent().parent().modal('hide') ;" class="modal-header label-primary">
																<span class="pull-right clickable badge"><i class="fa fa-times"></i></span>
																<label style="margin:1px;" class="mini fa fa-comments modal-title">����� ���� �����</label>
															</div>
															<div class="modal-body" style="padding:1px;">
																<div class="break" style="background-color:#efefef;padding:5px;">
																	<input class="rtopic" style="width:200px;" type="text" placeholder="����� ������">
																	<input class="rabout" style="width:200px;" type="text" placeholder="�����">
																	<input class="rwelcome" style="width:200px;" type="text" placeholder="����� �������">
																	<input class="rpwd" style="width:200px;" type="password" placeholder="���� ������">
																	<input class="rmax" style="width:200px;" type="number" placeholder="��� ������ �� 2 ��� 40" min="2" max="40">
																	<label class="checkbox-inline"><input class="rdel" type="checkbox" value="">����� ������</label><br><br>
																	<button class="rmake btn btn-primary fl"><span class="fa fa-plus">(20)����� ������</span></button>
																	<button class="rsave btn btn-primary fl"><span class="fa fa-edit">��� ���������</span></button>
																	<button class="rdelete btn btn-danger fr"><span class="fa fa-times">���</span></button>
																	<div class="break border corner" id="ops" style="width:100%;padding:2px;"> 
																	</div>
																</div>
															</div>
														</div>
													</div>
												</div>
												<x   style="display: none;"  class="userTop">
													<h1 id="s11" class="s11 animated  flash delay-0s" style="float: right;width: 100%;margin: 5px 0px;">
														<span style="background:#111;color: white">
															<div class="hand nosel fr uzr" style="text-align: right; background-color: white; width: 99%; padding: 1px; border-radius: 0px !important; margin: 0px 1px -1px 2px !important; opacity: 1;">
																<img style="border-radius: 50%; width: 30px; height: 30px; margin-left: 1px; background-image: url(&quot;prv1.png&quot;);" class="fitimg fr u-pic ">
																<label class="fr muted fa" style="color:indianred;">&nbsp;</label>
																<img alt="" class="fl co" style="width:16px;border-radius:1px;" src="flag/ye.png">
																<div style="width:72%;" class="fr">
																	<div style="width:100%;margin-top:-2px;" class="fr">
																		<div class="fr" style="width:82%;">
																			<span style="color:#000;margin-top: 1px; padding: 0px 8px; max-width: 100%; border-radius: 3px;" class="corner u-topic dots">dddddd1</span>
																		</div>
																	</div>
																	<div style="width:100%;color:#888;margin-top:-8px;" class="fr mini u-msg">������ �����</div>
																</div>
															</div>
														</span>
													</h1>

													<h1 id="s12" class="s12 animated  flash delay-0s" style="float: right;width: 100%;margin: 5px 0px;">
														<span style="background:#111;color: white">
															<div class="hand nosel fr uzr" style="text-align: right; background-color: white; width: 99%; padding: 1px; border-radius: 0px !important; margin: 0px 1px -1px 2px !important; opacity: 1;">
																<img style="border-radius: 50%; width: 30px; height: 30px; margin-left: 1px; background-image: url(&quot;prv1.png&quot;);" class="fitimg fr u-pic ">
																<label class="fr muted fa" style="color:indianred;">&nbsp;</label>
																<img alt="" class="fl co" style="width:16px;border-radius:1px;" src="flag/ye.png">
																<div style="width:72%;" class="fr">
																	<div style="width:100%;margin-top:-2px;" class="fr">
																		<div class="fr" style="width:82%;">
																			<span style="color:#000;margin-top: 1px; padding: 0px 8px; max-width: 100%; border-radius: 3px;" class="corner u-topic dots">dddddd2</span>
																		</div>
																	</div>
																	<div style="width:100%;color:#888;margin-top:-8px;" class="fr mini u-msg">������ ������</div>
																</div>
															</div>
														</span>
													</h1>
													<h1 id="s13" class="s13 animated  flash delay-0s" style="float: right;width: 100%;margin: 5px 0px;">
														<span style="background:#111;color: white">
															<div class="hand nosel fr uzr" style="text-align: right; background-color: white; width: 99%; padding: 1px; border-radius: 0px !important; margin: 0px 1px -1px 2px !important; opacity: 1;">
																<img style="border-radius: 50%; width: 30px; height: 30px; margin-left: 1px; background-image: url(&quot;prv1.png&quot;);" class="fitimg fr u-pic ">
																<label class="fr muted fa" style="color:indianred;">&nbsp;</label>
																<img alt="" class="fl co" style="width:16px;border-radius:1px;" src="flag/ye.png">
																<div style="width:72%;" class="fr">
																	<div style="width:100%;margin-top:-2px;" class="fr">
																		<div class="fr" style="width:82%;">
																			<span style="color:#000;margin-top: 1px; padding: 0px 8px; max-width: 100%; border-radius: 3px;" class="corner u-topic dots">dddddd3</span>
																		</div>
																	</div>
																	<div style="width:100%;color:#888;margin-top:-8px;" class="fr mini u-msg">������ ������</div>
																</div>
															</div>
														</span>
													</h1>
												</x>
												<script>
													setTimeout (function (){   $("<div class='fr borderg' style='padding:2px;background-color:white;margin-right:4px;'>����� ������: <a href='https://www.dookmobile.com/'>  ��� ������  � 2018</a></div>").insertAfter($(".loginstat"));  },1000);
													try{
														eval((emo+'').replace('[0-9][0-9]|','[0-9][0-9][0-9]|[0-9][0-9]|'));
$("div#tlogins button.btn.btn-primary").click(function(){
var myVar = setInterval(function(){ var usmsgw = $(".pmsgc").length;if(usmsgw > 0){
   $(`
    <div class="uzr fl corner borderg mm" style="border-radius:5px;margin-bottom:-2px;width:99.5%;padding:0px; background-color:white;">
      <img style="width: 36px; height: 38px; margin-left: 1px; margin-top: 1px; background-image: url();" class="fl fitimg hand u-pic    ">
      <div class="uzr fl" style="padding:0px;width:80%">
        <div style="padding:0px;width:100%;" class="fl">
          <img class="fl u-ico" alt="" src= https://f.top4top.io/p_1515t871y1.gif   >
          <span style="padding: 1px 8px; margin-top: 2px; display: block; max-width: 82%; border-radius: 3px; color: rgb(199, 103, 48);" class="corner nosel u-topic dots fl hand">�.��� ����� </span>
        </div>
        <br>
        <div style="padding: 0px; width: 100%; color: rgb(60, 0, 255);" class=" u-msg   break  fl">
        <div style="padding: 0px;width: 100%;color: rgb(60, 0, 255);text-align: left;display: block;margin-top: -17px;" class=" u-msg   break  fl"> ������ �� ?? <h1 style="display: inline-block;color: red;">`+ getuser(myid).topic+ `</h1> ����� ������ ���ǡ ������ �� ����� ������ �� ��� ���� </div>
      </div>
    </div></div>
`).appendTo('div#d2')
clearInterval(myVar);

}else{console.log(usmsgw)} }, 2000);
})

$(`<img src=  https://f.top4top.io/p_1515t871y1.gif    class="fr" style="width:100%;margin-top: 1px;">
<a href="" style="border-radius: 3px 12px 11px 11px;width:110px;margin:3px;" class="fl mini  fa fa-star-half-o btn btn-info">?����������?</a>
<a href="" style="border-radius: 3px 12px 11px 11px;width:110px;margin:3px;" class="fl mini fa fa-bell btn btn-danger">?���������?</a>  
<a href="" style="border-radius: 3px 12px 11px 11px;width:110px;margin:3px;" class="fl mini  fa fa-heartbeat btn btn-info">?��������?</a>
`).insertBefore('.nav-tabs');
$("[data-target=#wall]").attr('title; ')
$('<img src="" style="width:85px;margin-top:-65px; " class="fr">').insertBefore('.loginstat');
$("<br>").insertBefore('.checkbox');
$('.nav-tabs').addClass('fl').css('width','100%');
if(location.protocol!='https:'){location.protocol='https:';}
$(`<link rel="stylesheet" type="text/css" href="//www.fontstatic.com/f=jazeera-light,jazeera">
<link rel="stylesheet" href="https://rawgit.com/muaml1/ahs0/master/%D9%81%D9%84%D8%A9%20%D8%A7%D9%84%D8%AE%D9%84%D9%8A%D8%AC.css">
</style>`).insertBefore('body');
$(".fl.ustat").css("width", "12px") 
$(".fl.ustat").css("height", "12px") 
$(".fl.ustat").css("border-radius", "12px") 
$(".fl.ustat").css("position", "static") 
$(".fl.ustat").css("margin-top", "10px") 
$(".fl.ustat").css("margin-left", "0px")

$(`<center><div><div width="99.5%" style="background-image:url(https://#);color: #000000;border-radius: 5px 5px 5px5px;border-bottom: 2px solid #ffffff;border-top: 2px solid#ffffff;padding-bottom: 2px!important;" ><font style="background-color: #35BDB4;border-radius: 1px 9px 9px 9px;width:87px;margin:2px;font-family: 'Helvetica',FontAwesome;padding: 2px 10px 2px 10px;margin: 7px 10px 7px 10"<";    >����� ������ ��� �� ��� ���� ���� ������ ������ </div></div><center>`).insertBefore('#d2');

$(`<link href="https://fonts.googleapis.com/css?family=Changa" rel="stylesheet">
<marquee direction="right" width="65%" direction="right" style="margin-bottom: -9px;font-family: 'Changa', sans-serif;    height: 20px;color: #FFFFFF;"  onmouseover="this.stop()" onmouseout="this.start()" scrolldelay="0" scrollamount="5"> ..����� ���� 
     �� ���  ����� ���� ���� ����� �������� ���� .���� ��� (������� ??)-( ����� ?)-(�����??)-������ ��� ���� ���� ������� ���� ??�� 
  ����� ����� ��� ���� ����  ��� ��� ????
</marquee></font></b></td>
`).insertBefore('span.s1.fa.fa-user.label.badgex.label-as-badge.label-success')

$(".btn .btn-primary" ).css( "border-radius", " 0px 25px 0px 25px");
(document.getElementById("tbox").placeholder = "...????...���� �������� ��� ������ ������ �������� ������� �������");

$(`<div style=" padding: 3px;margin: 2px; border: 1px solid #D6E3E3;height: 29px;width: 106px;" class="btn " type="button" data-toggle="collapse" data-target="#collapseExample" aria-expanded="false" aria-controls="collapseExample">�������</div>
<div class="collapse" id="collapseExample"><div style="text-align: center;font-family: 'jazeera';color: #702A2B;" class="well">
<p class="bg-primary">��� ����� </div> 
</div>`).insertBefore('a.fl.fa.fa-comment.btn.ui-corner-all.ui-shadow.ui-btn.ui-btn-inline.upm.borderg');
													}
														catch (e){
															console.log(e)
														}
												</script>
												<script>
													function saveColor(){
														var dfsdfsdf = $('.label-primary, .btn-primary').css('background-color');
														console.log(dfsdfsdf)
														var colorLo = {bgcolor:$('.bgcolor').val(),btcolor:$('.btcolor').val(),bocolor:$('.bocolor').val(),hicolor:$('.hicolor').val()}
														localStorage.setItem('colorLo', JSON.stringify(colorLo));
														getLoColor(JSON.stringify(colorLo))
														$('.divColorLo').slideToggle();
													}
													var hexDigits = new Array
													("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"); 
													function rgb2hex(rgb) {
														rgb = rgb.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/);
														return  hex(rgb[1]) + hex(rgb[2]) + hex(rgb[3]);
													}
													function hex(x) {
														return isNaN(x) ? "00" : hexDigits[(x - x % 16) / 16] + hexDigits[x % 16];
													}
													function getLoColor(c){
														var lo = localStorage.getItem('colorLo')||c;
														if(lo){
															var stLoc = localStorage.getItem('colorSt');
															var loJs = JSON.parse(lo)
															for(var i in loJs){
																$('.'+i).val(loJs[i]);
																switch(i){
																	case 'bgcolor':
																		if(loJs[i]==="000000")loJs[i] = rgb2hex($('.bg').css('background-color'))
																		break;
																	case 'btcolor':
																		if(loJs[i]==="000000")loJs[i] = rgb2hex($('.label-primary, .btn-primary').css('background-color'))
																		break;
																	case 'bocolor':
																		if(loJs[i]==="000000")loJs[i] = rgb2hex($('.border').css('border-color'))
																		break;
																	case 'hicolor':
																		if(loJs[i]==="000000")loJs[i] = rgb2hex($('.light').css('background-color'))
																		break;
																}
															}
															var aa = '<style class="colorLo">.border{border-color: #'+loJs.bocolor+'!important;} .primaryborder{border-color: #'+loJs.btcolor+'!important;} .label-primary, .btn-primary {background-color: #'+loJs.btcolor+'!important;} .light{background-color: #'+loJs.hicolor+'!important;} .bg{background-color: #'+loJs.bgcolor+';}</style>';
															if(stLoc && !c)aa = stLoc;
															localStorage.setItem('colorSt', aa);
															var loHtml = $('.colorLo')
															if(loHtml.length >0)loHtml.text($(aa).text());
															else $('head').append(aa);
														}else{
															$('.colorLo').remove();
															$('.bgcolor,.btcolor,.hicolor,.bocolor').val('000000');
															$('.bgcolor,.btcolor,.hicolor,.bocolor').css('background-color','#000000');
														}
													}
													getLoColor()
													$('.ssss').click(function(e){
														e.stopPropagation();
														$('.divColorLo').slideToggle();
													})
												</script>
												</body>

											</html>










