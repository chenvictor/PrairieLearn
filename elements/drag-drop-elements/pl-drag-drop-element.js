/* eslint-env jquery, browser */

const TABWIDTH = 50;      // defines how many px the answer block is indented by, when the student
                          // drags and indents a block
const INDENT_OFFSET = 5;  // For aesthetic, all answer blocks are offseted to the right by
                          // 5px, so the answer tiles are not directly touching the dropzone margins
const MAX_INDENT = 4;     // defines the maximum number of times an answer block can be indented

function set_answer(event) {
    // We only care about when this function is fired
    // from an ANSWER DROPZONE, aka dropzones with yellow backgrounds 
    var textfield_name = event.target.getAttribute('name');
    var dom_objs = $('#' + textfield_name + '-dropzone').children();
    var student_answers = [];
    var indents = [];
    var answer_json = {'answers': [], 'answer_indent': []};
    for (var i = 0; i < dom_objs.length; i++) {
        if (!$(dom_objs[i]).hasClass('info')){
            var answer_text = dom_objs[i].getAttribute('string');
            var answer_indent = parseInt($(dom_objs[i]).css('marginLeft').replace('px', ''));
            answer_indent = Math.round((answer_indent - INDENT_OFFSET) / TABWIDTH); // get how many times the answer is indented
            student_answers.push(answer_text);
            indents.push(answer_indent.toString());
        }
    }

    textfield_name = event.target.getAttribute('name');
    if (textfield_name === null){
        return;
    }
    textfield_name = '#' + textfield_name + '-input';
    answer_json.answers = student_answers;
    answer_json.answer_indent = indents;
    $(textfield_name).val(JSON.stringify(answer_json));
}


function update_indent(leftDiff, id, ui) {
    if (!ui.item.parent()[0].classList.contains('dropzone')){
        // no need to support indent on MCQ option panel
        ui.item[0].style = 'margin-left: 5px;';
        return;
    }
    leftDiff = ui.position.left - ui.item.parent().position().left;
    var currentIndent = ui.item[0].style.marginLeft;
    if (parseInt(currentIndent) <= MAX_INDENT + 1 && leftDiff < 0){
        return; // if answer is not indented, and the student drag it left
                // do nothing
    }

    leftDiff = (Math.round(leftDiff / TABWIDTH) * TABWIDTH);

    // leftDiff is the direction to move the MCQ answer tile, in px
    // we limit leftDiff to be increments of TABWIDTH, whether positive or negative
    if (currentIndent != ''){
        leftDiff += parseInt(currentIndent); 
    }
    // limit leftDiff to be in [INDENT_OFFSET, (TABWIDTH * MAX_INDENT) + INDENT_OFFSET], within the bounds of the drag and drop box
    // that is, at least indented 0 times, or at most indented by MAX_INDENT times  
    leftDiff = Math.min(Math.max(leftDiff, INDENT_OFFSET), (TABWIDTH * MAX_INDENT) + INDENT_OFFSET);

    // when the user drag a tile into the answer box for the first time
    // the snap to grid dragging doesnt apply
    // so we have to manually enforce "snapping the leftDiff number to the nearest grid number" here
    var remainder = (leftDiff - INDENT_OFFSET) % TABWIDTH;
    if (remainder != 0) {
        // Manually snap to grid here, by rounding to the nearest multiple of TABWIDTH
        if (remainder > (TABWIDTH / 2)){
            leftDiff += remainder; // round towards +∞, to the next bigger multiple of TABWIDTH
        } else {
            leftDiff -= remainder; // round towards -∞, to the next smaller multiple of TABWIDTH
        }
    }

    ui.item[0].style = 'margin-left: ' + Math.max(leftDiff, INDENT_OFFSET) + 'px;';
}


$( document ).ready(function() {
    // Add drag and drop functionality for options elements
    // that has the connectedSortable class
    // code for the HTML popover
    $('.connectedSortable').sortable({
        items: 'li:not(.info-fixed)',
        cancel: '.info',
        connectWith: '.connectedSortable',
        placeholder: 'ui-state-highlight',
        create: function(event){
            // when the sortable is created, we need to put the two functions here
            // to restore progress when the user refresh/submits an answer
            set_answer(event);
        },
        stop: function(event, ui){
            // when the user stops interacting with the list
            update_indent(ui.position.left - ui.item.parent().position().left, ui.item[0].id, ui);
            set_answer(event);
        },
    }).disableSelection();
    $('.dropzone').sortable({
        grid: [TABWIDTH, 1],
    });
    $('[data-toggle="popover"]').popover();
});