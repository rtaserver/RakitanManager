if (void 0 === trbtn)
  var trbtn =
    trbtn ||
    (function () {
      var t = -1,
        n = [],
        r = "",
        e = "";
      return {
        init: function (o, a, i, c, l = 40, s = !1) {
          var p = t + 1;
          return (
            t++,
            (n[p] = { text: o, color: a, url: i, src: c, size: l / 40 }),
            (r =
              "#trbtn-container-" +
              p +
              " .trbtn-img{display: initial!important;vertical-align:middle;padding-top:0!important;padding-bottom:0!important;border:none;margin-top:0;margin-right:10px!important;margin-left:0!important;margin-bottom:3px!important;content:url('[src]')}.trbtn-container{display:inline-block!important;white-space:nowrap;min-width:110px}span.trbtn-txt{color:#fff !important;letter-spacing: -0.15px!important;text-wrap:none;vertical-align:middle;line-height:33px !important;padding:0;text-align:center;text-decoration:none!important; text-shadow: 0 1px 1px rgba(34, 34, 34, 0.05);}.trbtn-txt a{color:#fff !important;text-decoration:none:important;}.trbtn-txt a:hover{color:#fff !important;text-decoration:none}a.trbtn{box-shadow: 1px 1px 0px rgba(0, 0, 0, 0.2);line-height:36px!important;min-width:100px;display:inline-block!important;background-color:#be1e2d;padding:2px 24px !important;text-align:center !important;border-radius:9999px;color:#fff;cursor:pointer;overflow-wrap:break-word;vertical-align:middle;border:0 none #fff !important;font-family:'Quicksand',Helvetica,Century Gothic,sans-serif !important;text-decoration:none;text-shadow:none;font-weight:700!important;font-size:14px !important}a.trbtn:visited{color:#fff !important;text-decoration:none !important}a.trbtn:hover{opacity:.85;color:#f5f5f5 !important;text-decoration:none !important}a.trbtn:active{color:#f5f5f5 !important;text-decoration:none !important}.trbtn-txt img.trbtn-img {display: initial;animation: trbtn-wiggle 3s infinite; height: 22px;}"),
            (r +=
              "@keyframes trbtn-wiggle{0%{transform:rotate(0) scale(1)}60%{transform:rotate(0) scale(1)}75%{transform:rotate(0) scale(1.12)}80%{transform:rotate(0) scale(1.1)}84%{transform:rotate(-10deg) scale(1.1)}88%{transform:rotate(10deg) scale(1.1)}92%{transform:rotate(-10deg) scale(1.1)}96%{transform:rotate(10deg) scale(1.1)}100%{transform:rotate(0) scale(1)}}"),
            s ||
              ((e =
                "<link href='https://fonts.googleapis.com/css?family=Quicksand:400,700' rel='stylesheet' type='text/css'>"),
              (r += ".trbtn{transform-origin:top left;}")),
            (r = "<style>" + r + "</style>"),
            (e +=
              '<div id="trbtn-container-' +
              p +
              '" class="trbtn-container"><a title="Dukung saya di trakteer.id" class="trbtn" style="background-color:[color];transform:scale([size]);" href="[url]" target="_blank"> <span class="trbtn-txt"><img src="[src]" alt="Traktiran" class="trbtn-img"/><span>[text]</span></span></a></div>'),
            s ||
              window.addEventListener("DOMContentLoaded", function () {
                trbtn.updateSize(p);
              }),
            p
          );
        },
        updateSize: function (t) {
          var r,
            e,
            o,
            a = 0,
            i = setInterval(function () {
              r || (r = document.getElementById("trbtn-container-" + t)),
                r &&
                  document.body.contains(r) &&
                  (e || (e = r.querySelector(".trbtn")),
                  e.clientWidth !== a &&
                    ((r.style.width = e.clientWidth * n[t].size + "px"),
                    (r.style.height = e.clientHeight * n[t].size + "px")),
                  (a = e.clientWidth),
                  o || (o = e.querySelector(".trbtn-img")),
                  o.complete &&
                    document.fonts &&
                    document.fonts.check &&
                    document.fonts.check("bold 16px quicksand") &&
                    document.fonts.check("bolder 16px quicksand") &&
                    clearInterval(i));
            }, 100);
        },
        draw: function (t) {
          var o = n[t];
          document.writeln(
            r.replace("[src]", o.src) +
              e
                .replace("[color]", o.color)
                .replace("[text]", o.text)
                .replace("[src]", o.src)
                .replace("[url]", o.url)
                .replace("[size]", o.size)
          );
        },
      };
    })();
