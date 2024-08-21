if (void 0 === trbtnOverlay)
  var trbtnOverlay =
    trbtnOverlay ||
    (function () {
      var t = -1,
        e = [],
        n = null,
        r = "",
        o = "";
      return {
        init: function (a, i, l, c, d = 40, s = "inline", p = !1) {
          var m = t + 1;
          t++,
            (l += "?embedId=" + m),
            (e[m] = {
              text: a,
              color: i,
              url: l,
              src: c,
              size: d / 40,
              pos: s,
            }),
            (r =
              "#trbtn-overlay-container-" +
              m +
              " .trbtn-img{display: initial!important;vertical-align:middle;padding-top:0!important;padding-bottom:0!important;border:none;margin-top:0;margin-right:10px!important;margin-left:0!important;margin-bottom:3px!important;content:url('[src]')}.trbtn-overlay-container{display:inline-block!important;white-space:nowrap;min-width:110px}.trbtn-overlay-container.floating-left{position:fixed;bottom:20px;left:20px}.trbtn-overlay-container.floating-right{position:fixed;bottom:20px;right:20px}span.trbtn-txt{color:#fff !important;letter-spacing: -0.15px!important;text-wrap:none;vertical-align:middle;line-height:33px !important;padding:0;text-align:center;text-decoration:none!important; text-shadow: 0 1px 1px rgba(34, 34, 34, 0.05);}.trbtn-txt a{color:#fff !important;text-decoration:none:important;}.trbtn-txt a:hover{color:#fff !important;text-decoration:none}a.trbtn{box-shadow: 1px 1px 0px rgba(0, 0, 0, 0.2);line-height:36px!important;min-width:100px;display:inline-block!important;background-color:#be1e2d;padding:2px 24px !important;text-align:center !important;border-radius:9999px;color:#fff;cursor:pointer;overflow-wrap:break-word;vertical-align:middle;border:0 none #fff !important;font-family:'Quicksand',Helvetica,Century Gothic,sans-serif !important;text-decoration:none;text-shadow:none;font-weight:700!important;font-size:14px !important}a.trbtn:visited{color:#fff !important;text-decoration:none !important}a.trbtn:hover{opacity:.85;color:#f5f5f5 !important;text-decoration:none !important}a.trbtn:active{color:#f5f5f5 !important;text-decoration:none !important}.trbtn-txt img.trbtn-img {display: initial;animation: trbtn-wiggle 3s infinite; height: 22px;}"),
            (r +=
              "@keyframes trbtn-wiggle{0%{transform:rotate(0) scale(1)}60%{transform:rotate(0) scale(1)}75%{transform:rotate(0) scale(1.12)}80%{transform:rotate(0) scale(1.1)}84%{transform:rotate(-10deg) scale(1.1)}88%{transform:rotate(10deg) scale(1.1)}92%{transform:rotate(-10deg) scale(1.1)}96%{transform:rotate(10deg) scale(1.1)}100%{transform:rotate(0) scale(1)}}"),
            p ||
              ((r += ".trbtn{transform-origin:top left;}"),
              (n =
                "https://fonts.googleapis.com/css?family=Quicksand:400,700")),
            (o =
              '<div id="trbtn-overlay-container-' +
              m +
              '" class="trbtn-overlay-container [pos]"><a title="Dukung saya di trakteer.id" class="trbtn" style="background-color:[color];transform:scale([size]);" target="_blank"><span class="trbtn-txt"><img src="[src]" alt="Traktiran" class="trbtn-img"/><span>[text]</span></span></a></div>');
          var f = !1,
            b = !1,
            u = "",
            g = function () {
              var t = function (t) {
                b ||
                  ((b = !0),
                  t.addEventListener(
                    "click",
                    function () {
                      if (!f) {
                        var t = document.querySelector(
                          "#trbtn-overlay-container-" + m + " .trbtn-txt"
                        );
                        (u = t.innerHTML), (t.innerHTML = "Loading...");
                        var e = document.createElement("div");
                        e.setAttribute("id", "trbtn-overlay-" + m),
                          (e.style.cssText =
                            "display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:9999999");
                        var n = document.createElement("iframe");
                        (n.onload = function () {
                          t.innerHTML = u;
                        }),
                          (n.src = l + "&ref=" + window.location.href),
                          (n.style.cssText = "width:100%;height:100%;border:0"),
                          e.appendChild(n),
                          document.body.appendChild(e),
                          (f = !0),
                          window.addEventListener("message", function (t) {
                            "embed.modalClosed" == t.data.type &&
                              setTimeout(function () {
                                e.style.display = "none";
                              }, 200);
                          });
                      }
                      var r = document.querySelector(
                        "#trbtn-overlay-" + m + " iframe"
                      );
                      r &&
                        ((document.getElementById(
                          "trbtn-overlay-" + m
                        ).style.display = "block"),
                        r.contentWindow.postMessage(
                          { type: "embed.openModal" },
                          "*"
                        ));
                    },
                    !1
                  ));
              };
              p
                ? t(
                    document
                      .getElementById("trbtn-overlay-container-" + m)
                      .querySelector(".trbtn")
                  )
                : trbtnOverlay.updateSize(m, t);
            };
          return (
            "loading" === document.readyState
              ? document.addEventListener("DOMContentLoaded", g)
              : g(),
            m
          );
        },
        updateSize: function (t, n = null) {
          var r,
            o,
            a,
            i = 0,
            l = setInterval(function () {
              r ||
                (r = document.getElementById("trbtn-overlay-container-" + t)),
                r &&
                  document.body.contains(r) &&
                  (o || (o = r.querySelector(".trbtn")),
                  o.clientWidth !== i &&
                    ((r.style.width = o.clientWidth * e[t].size + "px"),
                    (r.style.height = o.clientHeight * e[t].size + "px"),
                    n && n(r)),
                  (i = o.clientWidth),
                  a || (a = o.querySelector(".trbtn-img")),
                  a.complete &&
                    document.fonts &&
                    document.fonts.check &&
                    document.fonts.check("bold 16px quicksand") &&
                    document.fonts.check("bolder 16px quicksand") &&
                    clearInterval(l));
            }, 100);
        },
        draw: function (t) {
          var a = e[t],
            i = document.createElement("style");
          if (
            ((i.innerHTML = r.replace("[src]", a.src)),
            document.head.appendChild(i),
            n)
          ) {
            var l = document.createElement("link");
            (l.href = n),
              (l.rel = "stylesheet"),
              (l.type = "text/css"),
              document.head.appendChild(l);
          }
          var c = document.querySelectorAll("script.troverlay")[t],
            d = document.createElement("div");
          (d.innerHTML = o
            .replace("[color]", a.color)
            .replace("[text]", a.text)
            .replace("[src]", a.src)
            .replace("[url]", a.url)
            .replace("[size]", a.size)
            .replace("[pos]", a.pos)),
            c.parentNode.insertBefore(d.firstChild, c);
        },
      };
    })();
