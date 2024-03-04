{{$svrType := .ServiceType}}
{{$svrName := .ServiceName}}

{{- range .MethodSets}}
const Operation{{$svrType}}{{.OriginalName}} = "/{{$svrName}}/{{.OriginalName}}"
{{- end}}


/************************************/
/********* API INTERFACE *********/
/************************************/


type {{.ServiceType}}HTTPServer interface {
{{- range .MethodSets}}
	{{- if ne .Comment ""}}
	{{.Comment}}
	{{- end}}
	{{.Name}}(*gin.Context, *{{.Request}}) (*{{.Reply}}, error)
{{- end}}
}

func Register{{.ServiceType}}HTTPServer(r *gin.Engine, srv {{.ServiceType}}HTTPServer, coder gin_codec.Codec) {
	{{- range .Methods}}
	r.{{.Method}}("{{.Path}}", _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(srv, coder))
	{{- end}}
}

/************************************/
/********* API HANDLERs *********/
/************************************/

{{range .Methods}}
func _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(srv {{$svrType}}HTTPServer, coder gin_codec.Codec) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		var in {{.Request}}
		{{- if .HasBody}}
		if err := coder.Bind(ctx, &in{{.Body}}); err != nil {
			_ = ctx.Error(err)
			return
		}
		{{- end}}
		if err := coder.BindQuery(ctx, &in); err != nil {
			_ = ctx.Error(err)
			return
		}
		{{- if .HasVars}}
		if err := coder.BindVars(ctx, &in); err != nil {
			_ = ctx.Error(err)
			return
		}
		{{- end}}

		out, err := srv.{{.Name}}(ctx, &in)
		if err != nil {
			_ = ctx.Error(err)
			return
		}

		err = coder.Result(ctx, out)
		if err != nil {
			_ = ctx.Error(err)
			return
		}
	}
}
{{end}}

type {{.ServiceType}}HTTPClient interface {
{{- range .MethodSets}}
	{{.Name}}(ctx context.Context, req *{{.Request}}, opts ...http.CallOption) (rsp *{{.Reply}}, err error)
{{- end}}
}

type {{.ServiceType}}HTTPClientImpl struct{
	cc *http.Client
}

func New{{.ServiceType}}HTTPClient (client *http.Client) {{.ServiceType}}HTTPClient {
	return &{{.ServiceType}}HTTPClientImpl{client}
}

{{range .MethodSets}}
func (c *{{$svrType}}HTTPClientImpl) {{.Name}}(ctx context.Context, in *{{.Request}}, opts ...http.CallOption) (*{{.Reply}}, error) {
	var out {{.Reply}}
	pattern := "{{.Path}}"
	path := binding.EncodeURL(pattern, in, {{not .HasBody}})
	opts = append(opts, http.Operation(Operation{{$svrType}}{{.OriginalName}}))
	opts = append(opts, http.PathTemplate(pattern))
	{{if .HasBody -}}
	err := c.cc.Invoke(ctx, "{{.Method}}", path, in{{.Body}}, &out{{.ResponseBody}}, opts...)
	{{else -}}
	err := c.cc.Invoke(ctx, "{{.Method}}", path, nil, &out{{.ResponseBody}}, opts...)
	{{end -}}
	if err != nil {
		return nil, err
	}
	return &out, err
}
{{end}}
