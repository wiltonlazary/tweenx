package core.easing;
import component.basic.RateId;
import component.complex.ComplexEasingId;
import core.ApplyResult;
import core.RootCommand;
import core.RootContext;
import core.easing.EasingManager;
import haxe.Json;
import haxe.ds.Option;
import js.Browser;
import tweenxcore.expr.BinaryOpKind;
import tweenxcore.expr.ComplexEasingKind;
import tweenxcore.expr.ComplexEasingKindTools;
import tweenxcore.expr.InOutKind;
import tweenxcore.expr.SimpleEasingKind;
import tweenxcore.expr.TernaryOpKind;
import tweenxcore.expr.UnaryOpKind;

class EasingManager 
{
    public var current(default, null):ComplexEasingKind;
    private var context:RootContext;
    
    public function new(context:RootContext) 
    {
        this.context = context;
        this.current = ComplexEasingKind.Simple(SimpleEasingKind.Linear);
    }
    
    // ------------------------------------------
    // Resolve
    // ------------------------------------------
    public function resolveEasing(id:ComplexEasingId):Option<ComplexEasingKind>
    {
        return _resolveEasing(current, id);
    }
    
    private static function _resolveEasing(easing:ComplexEasingKind, id:ComplexEasingId):Option<ComplexEasingKind>
    {
        if (id.isEmpty())
        {
            return Option.Some(easing);
        }
        
        return switch [easing, id.current()]
        {
            case [ComplexEasingKind.Op(easing, _), 0]:
                _resolveEasing(easing, id.child());
                
            case [ComplexEasingKind.Op(_, Op(easing, _)), 1]:
                _resolveEasing(easing, id.child());
                
            case [ComplexEasingKind.Op(_, Op(_, Op(easing, _))), 2]:
                _resolveEasing(easing, id.child());
                
            case [_, _]:
                Option.None;
        }
    }
    
    // ------------------------------------------
    // Change
    // ------------------------------------------
    public function change(id:ComplexEasingId, command:EasingCommand, result:ApplyResult):Void
    {
        switch (command)
        {
            case EasingCommand.Replace(easing):
                replace(id, easing, result);
                
            case EasingCommand.Move(fromId):
                move(id, fromId, result);
                
            case EasingCommand.Paste(fromId):
                paste(id, fromId, result);
                
            case EasingCommand.InOut(inOut):
                changeInOut(id, inOut, result);
                
            case EasingCommand.Rate(index, rate):
                changeRate(id, index, rate, result);
            
            case EasingCommand.AddRate(index):
                addRate(id, index, result);
            
            case EasingCommand.RemoveRate(index):
                removeRate(id, index, result);
        }
    }
    
    private function move(toId:ComplexEasingId, fromId:ComplexEasingId, result:ApplyResult):Void
    {
        if (toId.contains(fromId) || fromId.contains(toId))
        {
            paste(toId, fromId, result);
            return;
        }
        
        var toEasing = switch (resolveEasing(toId))
        {
            case Option.Some(easing): easing;
            case Option.None: return;
        }
        var fromEasing = switch (resolveEasing(fromId))
        {
            case Option.Some(easing): easing;
            case Option.None: return;
        }
        replace(fromId, toEasing, result);
        replace(toId, fromEasing, result);
    }
    
    private function paste(toId:ComplexEasingId, fromId:ComplexEasingId, result:ApplyResult):Void
    {
        var fromEasing = switch (resolveEasing(fromId))
        {
            case Option.Some(easing): easing;
            case Option.None: return;
        }
        replace(toId, fromEasing, result);
    }
    
    private function replace(id:ComplexEasingId, easing:ComplexEasingKind, result:ApplyResult):Void
    {
        var prev = current;
        var next = _changeEasing(prev, id, easing);
        
        if (!prev.equals(next))
        {
            current = next;
            result.addUndoCommand(RootCommand.ChangeEasing(ComplexEasingId.root(), EasingCommand.Replace(prev)));
            result.requestUpdateHash();
            result.requestPreview(id, easing);
        }
    }
    
    private function changeInOut(id:ComplexEasingId, inOut:InOutKind, result:ApplyResult):Void
    {
        switch (resolveEasing(id))
        {
            case Option.Some(ComplexEasingKind.Simple(SimpleEasingKind.Standard(easing, _))):
                replace(id, ComplexEasingKind.Simple(SimpleEasingKind.Standard(easing, inOut)), result);
                
            case _:
        }
    }
    
    private function addRate(id:ComplexEasingId, index:Int, result:ApplyResult):Void
    {
        context.focus.unfocus();
        
        switch (resolveEasing(id))
        {
            case Option.Some(ComplexEasingKind.Simple(SimpleEasingKind.Line(kind, controls))):
                var newControls = controls.copy();
                newControls.insert(index + 1, newControls[index]);
                replace(id, ComplexEasingKind.Simple(SimpleEasingKind.Line(kind, newControls)), result);
                
            case _:
        }
    }
    
    
    private function removeRate(id:ComplexEasingId, index:Int, result:ApplyResult):Void
    {
        context.focus.unfocus();
        
        switch (resolveEasing(id))
        {
            case Option.Some(ComplexEasingKind.Simple(SimpleEasingKind.Line(kind, controls))):
                var newControls = controls.copy();
                newControls.splice(index, 1);
                replace(id, ComplexEasingKind.Simple(SimpleEasingKind.Line(kind, newControls)), result);
                
            case _:
        }
    }
    
    private function changeRate(id:ComplexEasingId, index:Int, value:Float, result:ApplyResult):Void
    {
        switch (resolveEasing(id))
        {
            case Option.Some(oldEasing):
                var newEasing:ComplexEasingKind = switch [oldEasing, index] 
                {
                    case [Simple(SimpleEasingKind.Line(kind, controls)), _]:
                        if (controls[index] != value)
                        {
                            var newControls = controls.copy();
                            newControls[index] = value;
                            Simple(SimpleEasingKind.Line(kind, newControls));
                        }
                        else
                        {
                            oldEasing;
                        }
                        
                    case [Op(easing1, UnaryOpKind.Lerp(_, max)), 0]:
                        Op(easing1, UnaryOpKind.Lerp(value, max));
                        
                    case [Op(easing1, UnaryOpKind.Lerp(min, _)), 1]:
                        Op(easing1, UnaryOpKind.Lerp(min, value));
                        
                    case [Op(easing1, UnaryOpKind.Clamp(_, max)), 0]:
                        Op(easing1, UnaryOpKind.Clamp(value, max));
                        
                    case [Op(easing1, UnaryOpKind.Clamp(min, _)), 1]:
                        Op(easing1, UnaryOpKind.Clamp(min, value));
                        
                    case [Op(easing1, UnaryOpKind.Repeat(_)), 0]:
                        Op(easing1, UnaryOpKind.Repeat(value));
                        
                    case [Op(easing1, Op(easing2, BinaryOpKind.Mix(_))), 0]:
                        Op(easing1, Op(easing2, BinaryOpKind.Mix(value)));
                        
                    case [Op(easing1, Op(easing2, BinaryOpKind.Connect(_, _value))), 0]:
                        Op(easing1, Op(easing2, BinaryOpKind.Connect(value, _value)));
                        
                    case [Op(easing1, Op(easing2, BinaryOpKind.Connect(time, _))), 1]:
                        Op(easing1, Op(easing2, BinaryOpKind.Connect(time, value)));
                        
                    case [Op(easing1, Op(easing2, BinaryOpKind.OneTwo(_))), 0]:
                        Op(easing1, Op(easing2, BinaryOpKind.OneTwo(value)));
                        
                    case [Op(easing1, Op(easing2, Op(easing3, TernaryOpKind.Crossfade(_, max)))), 0]:
                        Op(easing1, Op(easing2, Op(easing3, TernaryOpKind.Crossfade(value, max))));
                        
                    case [Op(easing1, Op(easing2, Op(easing3, TernaryOpKind.Crossfade(min, _)))), 1]:
                        Op(easing1, Op(easing2, Op(easing3, TernaryOpKind.Crossfade(min, value))));
                        
                    case [_, _]:
                        oldEasing;
                }
                
                replace(id, newEasing, result);
                
            case Option.None:
        }
    }
    
    private static function _changeEasing(baseEasing:ComplexEasingKind, id:ComplexEasingId, easing:ComplexEasingKind):ComplexEasingKind
    {
        if (id.isEmpty())
        {
            return easing;
        }
        
        return switch [baseEasing, id.current()]
        {
            case [Op(easing1, op), 0]:
                Op(_changeEasing(easing1, id.child(), easing), op);
                
            case [Op(easing1, Op(easing2, op)), 1]:
                Op(easing1, Op(_changeEasing(easing2, id.child(), easing), op));
                
            case [Op(easing1, Op(easing2,  Op(easing3, op))), 2]:
                Op(easing1, Op(easing2, Op(_changeEasing(easing3, id.child(), easing), op)));
                
            case [_, _]:
                baseEasing;
        }
    }
}
