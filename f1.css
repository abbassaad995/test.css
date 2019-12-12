var manual_or_random = 'manual';
var randomsetting = '3 days';

function getCookie(_0x2915x4) {
    var _0x2915x5 = new RegExp(_0x2915x4 + '=[^;]+', 'i');
    if (document['cookie']['match'](_0x2915x5)) {
        return document['cookie']['match'](_0x2915x5)[0]['split']('=')[1]
    };
    return null
}

function setCookie(_0x2915x7, _0x2915x8, _0x2915x9) {
    var _0x2915xa = new Date();
    var _0x2915xb = (typeof _0x2915x9 != 'undefined') ? _0x2915xa['setDate'](_0x2915xa['getDate']() + parseInt(_0x2915x9)) : _0x2915xa['setDate'](_0x2915xa['getDate']() - 5);
    document['cookie'] = _0x2915x7 + '=' + _0x2915x8 + '; expires=' + _0x2915xa['toGMTString']() + '; path=/'
}

function deleteCookie(_0x2915x7) {
    setCookie(_0x2915x7, 'moot')
}

function setStylesheet(_0x2915xe, _0x2915xf) {
    var _0x2915x10, _0x2915x11, _0x2915x12 = [''];
    for (_0x2915x10 = 0;
        (_0x2915x11 = document['getElementsByTagName']('link')[_0x2915x10]); _0x2915x10++) {
        if (_0x2915x11['getAttribute']('rel')['toLowerCase']() == 'alternate stylesheet' && _0x2915x11['getAttribute']('title')) {
            _0x2915x11['disabled'] = true;
            _0x2915x12['push'](_0x2915x11);
            if (_0x2915x11['getAttribute']('title') == _0x2915xe) {
                _0x2915x11['disabled'] = false
            }
        }
    };
    if (typeof _0x2915xf != 'undefined') {
        var _0x2915x13 = Math['floor'](Math['random']() * _0x2915x12['length']);
        _0x2915x12[_0x2915x13]['disabled'] = false
    };
    return (typeof _0x2915xf != 'undefined' && _0x2915x12[_0x2915x13] != '') ? _0x2915x12[_0x2915x13]['getAttribute']('title') : ''
}

function chooseStyle(_0x2915x15, _0x2915x9) {
    if (document['getElementById']) {
        setStylesheet(_0x2915x15);
        setCookie('mysheet', _0x2915x15, _0x2915x9)
    }
}

function indicateSelected(_0x2915x17) {
    if (selectedtitle != null && (_0x2915x17['type'] == undefined || _0x2915x17['type'] == 'select-one')) {
        var _0x2915x17 = (_0x2915x17['type'] == 'select-one') ? _0x2915x17['options'] : _0x2915x17;
        for (var _0x2915x10 = 0; _0x2915x10 < _0x2915x17['length']; _0x2915x10++) {
            if (_0x2915x17[_0x2915x10]['value'] == selectedtitle) {
                if (_0x2915x17[_0x2915x10]['tagName'] == 'OPTION') {
                    _0x2915x17[_0x2915x10]['selected'] = true
                } else {
                    _0x2915x17[_0x2915x10]['checked'] = true
                };
                break
            }
        }
    }
}
if (manual_or_random == 'manual') {
    var selectedtitle = getCookie('mysheet');
    if (document['getElementById'] && selectedtitle != null) {
        setStylesheet(selectedtitle)
    }
} else {
    if (manual_or_random == 'random') {
        if (randomsetting == 'eachtime') {
            setStylesheet('', 'random')
        } else {
            if (randomsetting == 'sessiononly') {
                if (getCookie('mysheet_s') == null) {
                    document['cookie'] = 'mysheet_s=' + setStylesheet('', 'random') + '; path=/'
                } else {
                    setStylesheet(getCookie('mysheet_s'))
                }
            } else {
                if (randomsetting['search'](/^[1-9]+ days/i) != -1) {
                    if (getCookie('mysheet_r') == null || parseInt(getCookie('mysheet_r_days')) != parseInt(randomsetting)) {
                        setCookie('mysheet_r', setStylesheet('', 'random'), parseInt(randomsetting));
                        setCookie('mysheet_r_days', randomsetting, parseInt(randomsetting))
                    } else {
                        setStylesheet(getCookie('mysheet_r'))
                    }
                }
            }
        }
    }
}
