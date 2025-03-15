dialogOpen = false;
resourceName = null;
buttonClicked = {};

window.addEventListener('message', function(event) {
    ed = event.data;
    if (ed.action === "openDialog") {
        // Position the dialog based on alignment
        if (ed.menuAlign === "left") {
            document.getElementById("mainDiv").style.left = 0;
        } else {
            document.getElementById("mainDiv").style.right = 0;
        }
        buttonClicked = {};
        dialogOpen = true;
        document.getElementById("mainDiv").style.display = "flex";
        resourceName = ed.resourceName;

        // Update header and description
        document.getElementById("topDescription").innerHTML = ed.menuData.Description;
        document.getElementById("MDDivType1InsideIconDiv").innerHTML = `<i class="${ed.menuData.Icon}"></i>`;

        // Clear text area and append auto messages
        document.getElementById("MDDivType2BottomDiv").innerHTML = "";
        if (ed.autoMessages) {
            ed.autoMessages.forEach(function(messageData) {
                var messagesHTML = "";
                if (messageData.type === "question") {
                    messagesHTML = `
                    <div id="MDDivType2BDTarget">
                        <div id="MDDivType2BDTargetLine"></div>
                        <div id="MDDivType2BDTextDiv">${messageData.text}</div>
                        <div id="MDDivType2BDIconDiv">
                            <i class="fas fa-question-circle"></i>
                        </div>
                    </div>`;
                } else {
                    messagesHTML = `
                    <div id="MDDivType2BDTarget">
                        <div id="MDDivType2BDTargetLine"></div>
                        <div id="MDDivType2BDTextDiv">${messageData.text}</div>
                        <div id="MDDivType2BDIconDiv"></div>
                    </div>`;
                }
                appendHtml(document.getElementById("MDDivType2BottomDiv"), messagesHTML);
            });
        }

        // Clear and then create buttons without icon/number element
        document.getElementById("MDDivType3").innerHTML = "";
        ed.buttons.forEach(function(buttonData) {
            let a = buttonData.systemAnswer.text.replace(/'/g, '');
            let b = buttonData.playerAnswer.text.replace(/'/g, '');
            // Generate button HTML with only the text element
            var buttonsHTML = `
            <div class="MDDivType3Btn MDDivType3BtnDefault" id="MDDivType3Btn-${buttonData.label}" onclick="clFunc('answer', '${a}', '${buttonData.systemAnswer.type}', '${buttonData.systemAnswer.enable}', '${b}', '${buttonData.playerAnswer.enable}', '${buttonData.id}', '${buttonData.label}', '${buttonData.maxClick}')">
                <div class="MDDivType3BtnText">${buttonData.label}</div>
            </div>`;
            appendHtml(document.getElementById("MDDivType3"), buttonsHTML);
            buttonClicked[buttonData.label] = 0;
        });
    } else if (ed.action === "closeMenu") {
        dialogOpen = false;
        document.getElementById("mainDiv").style.display = "none";
    }
    document.onkeyup = function(data) {
        if (data.which == 27 && dialogOpen) {
            dialogOpen = false;
            document.getElementById("mainDiv").style.display = "none";
            var xhr = new XMLHttpRequest();
            xhr.open("POST", `https://${resourceName}/callback`, true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.send(JSON.stringify({ action: "nuiFocus" }));
        }
    };
});

function clFunc(action1, action2, action3, action4, action5, action6, action7, action8, action9) {
    if (action1 === "closeMenu") {
        dialogOpen = false;
        document.getElementById("mainDiv").style.display = "none";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", `https://${resourceName}/callback`, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.send(JSON.stringify({ action: "nuiFocus" }));
    } else if (action1 === "answer") {
        if (buttonClicked[action8] < Number(action9)) {
            buttonClicked[action8] = buttonClicked[action8] + 1;
            var xhr = new XMLHttpRequest();
            xhr.open("POST", `https://${resourceName}/callback`, true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.send(JSON.stringify({ action: "onClick", id: Number(action7) }));
            if (action2 && action4 === "true") {
                var messageHTML = "";
                if (action3 === "question") {
                    messageHTML = `
                    <div id="MDDivType2BDTarget">
                        <div id="MDDivType2BDTargetLine"></div>
                        <div id="MDDivType2BDTextDiv">${action2}</div>
                        <div id="MDDivType2BDIconDiv">
                            <i class="fas fa-question-circle"></i>
                        </div>
                    </div>`;
                } else {
                    messageHTML = `
                    <div id="MDDivType2BDTarget">
                        <div id="MDDivType2BDTargetLine"></div>
                        <div id="MDDivType2BDTextDiv">${action2}</div>
                        <div id="MDDivType2BDIconDiv"></div>
                    </div>`;
                }
                appendHtml(document.getElementById("MDDivType2BottomDiv"), messageHTML);
            }
            setTimeout(() => {
                if (action5 && action6 === "true") {
                    var messageHTML = `
                    <div id="MDDivType2BDMe">
                        <div id="MDDivType2BDMeTextDiv">${action5}</div>
                        <div id="MDDivType2BDMeTargetLine"></div>
                    </div>`;
                    appendHtml(document.getElementById("MDDivType2BottomDiv"), messageHTML);
                }
            }, 500);
            var objDiv = document.getElementById("MDDivType2BottomDiv");
            objDiv.scrollTop = objDiv.scrollHeight;
        }
        if (buttonClicked[action8] === Number(action9)) {
            document.getElementById("MDDivType3Btn-" + action8).classList.add("MDDivType3BtnClicked");
            document.getElementById("MDDivType3Btn-" + action8).classList.remove("MDDivType3BtnDefault");
        }
    }
}

function appendHtml(el, str) {
    var div = document.createElement('div');
    div.innerHTML = str;
    while (div.children.length > 0) {
        el.appendChild(div.children[0]);
    }
}
