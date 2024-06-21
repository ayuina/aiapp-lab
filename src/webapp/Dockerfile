FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore 
RUN dotnet build 
RUN dotnet publish -o ./publish

# final stage/image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /src/publish ./
ENV ASPNETCORE_URLS=http://+:80
ENTRYPOINT ["dotnet", "webapp.dll"]