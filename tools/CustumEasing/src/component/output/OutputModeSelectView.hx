package component.output;
import api.react.ReactComponent;
import api.react.ReactComponent.ReactComponentOfProps;
import component.basic.SelectGroupView;
import component.output.OutputModeSelectView;
import core.RootCommand;
import core.RootContext;
import core.output.OutputManager;
import core.output.OutputMode;
import haxe.EnumTools;
import haxe.ds.Option;
import tweenxcore.expr.ComplexEasingKind;

class OutputModeSelectView extends ReactComponentOfProps<OutputModeSelectProps>
{
    public function new(props:OutputModeSelectProps) 
    {
        super(props);
    }
    
    override public function render():ReactComponent 
    {
        var output = props.context.output;
        return "div".createElement(
            { className: "output-mode-select" },
            OutputModeView.createElement(
                {
                    {
                        current: Option.Some(output.mode),
                        data: [for(c in EnumTools.getConstructors(OutputMode)) EnumTools.createByName(OutputMode, c)],
                        onSelect: onSelect,
                        getName: props.context.localize.resource.outputMode,
                        getIcon: getIcon,
                    }
                }
            )
        );
    }
    
    private function onSelect(mode:OutputMode):Void
    {
        props.context.apply(RootCommand.ChangeOutputMode(mode), true);
    }
    
    private static function getIcon(mode:OutputMode):Option<String>
    {
        return Option.None;
    }
    
}

typedef OutputModeSelectProps =
{
    context: RootContext,
}

private typedef OutputModeView = SelectGroupView<OutputMode>;
